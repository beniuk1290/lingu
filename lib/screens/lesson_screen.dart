import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/providers/accounts_provider.dart';
import 'package:linguapilot/providers/dictionary_provider.dart';
import 'package:linguapilot/providers/settings_provider.dart';
import 'package:linguapilot/screens/accounts_screen.dart';
import 'package:linguapilot/services/bot_config.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum BotStatus { idle, running, paused, finished }

class _LogLine {
  final DateTime ts;
  final String text;
  final bool error;
  _LogLine(this.ts, this.text, {this.error = false});
}

/// Ekran nauki: WebView z InstaLing + sterowanie botem i dziennik sesji.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  InAppWebViewController? _controller;
  BotStatus _status = BotStatus.idle;
  final List<_LogLine> _log = [];

  int _answered = 0;
  int _sessionNewWords = 0;
  bool _userStarted = false;
  bool _showLog = false;
  String? _hint;
  String? _engineJs;

  /// Ciasteczka aktywnego konta przywracamy PRZED pierwszym załadowaniem.
  late final Future<void> _cookiesReady = _restoreCookies();

  Future<void> _restoreCookies() async {
    final account = context.read<AccountsProvider>().active;
    if (account != null) await restoreCookiesFor(account);
  }

  /// Zapisuje adres panelu ucznia wykryty podczas sesji (np. po ręcznym
  /// zalogowaniu w tej WebView), żeby następny start był szybki.
  Future<void> _capturePanelUrl(String? url) async {
    if (url == null) return;
    final isPanel = RegExp(r'mainPage\.php\?student_id=\d+').hasMatch(url) ||
        url.contains('html_app/app.php?');
    if (!isPanel) return;
    final provider = context.read<AccountsProvider>();
    final active = provider.active;
    if (active == null) return;
    await provider.savePanelUrl(active, url);
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadEngine();
  }

  Future<void> _loadEngine() async {
    final js = await BotConfig.engineScript;
    if (!mounted) return;
    setState(() => _engineJs = js);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _addLog(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _log.add(_LogLine(DateTime.now(), text, error: error));
      if (_log.length > 300) _log.removeAt(0);
    });
  }

  // ---------- mostek JS <-> Flutter ----------

  Future<void> _injectEngine() async {
    final c = _controller;
    if (c == null || _engineJs == null) return;
    await c.evaluateJavascript(source: _engineJs!);
    if (!mounted) return;
    final settings = context.read<SettingsProvider>().s;
    final lang = settings.lessonLang;
    final dict =
        context.read<DictionaryProvider>().asBotDict(lang);
    final config = BotConfig.build(
      settings: settings,
      dictionary: dict,
      lang: lang,
    );
    await c.evaluateJavascript(source: BotConfig.configure(config));
  }

  void _onBotEvent(dynamic args) {
    if (!mounted || args == null || args.isEmpty) return;
    String raw;
    if (args.first is String) {
      raw = args.first as String;
    } else {
      raw = jsonEncode(args.first);
    }
    Map<String, dynamic> ev;
    try {
      ev = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = ev['type'] as String? ?? '';
    final stats = (ev['stats'] as Map?)?.cast<String, dynamic>();

    switch (type) {
      case 'state':
        final s = ev['state'] as String? ?? '';
        if (s == 'running') {
          setState(() => _status = BotStatus.running);
        } else if (s == 'paused') {
          setState(() => _status = BotStatus.paused);
        } else if (s == 'stopped') {
          setState(() => _status = BotStatus.idle);
        }
        break;

      case 'word':
        final src = ev['src'] as String? ?? '';
        final dst = ev['dst'] as String? ?? '';
        final lang =
            ev['lang'] as String? ?? context.read<SettingsProvider>().s.lessonLang;
        if (src.isNotEmpty && dst.isNotEmpty) {
          context.read<DictionaryProvider>().upsert(lang, src, dst);
          setState(() => _sessionNewWords++);
          _addLog('📝 $src → $dst');
        }
        break;

      case 'progress':
        setState(() => _answered = stats?['answered'] as int? ?? _answered);
        _maybeEnforceWordLimit();
        break;

      case 'sessionEnd':
        _onSessionEnd(stats);
        break;

      case 'loginRequired':
        setState(() => _hint = tr(context).lessonHintLogin);
        _addLog('⚠ ${tr(context).lessonHintLogin}');
        break;

      case 'log':
        final msg = ev['msg'] as String? ?? '';
        final isErr = ev['level'] == 'error';
        if (!isErr && !context.read<SettingsProvider>().s.debugLog) break;
        if (msg.isNotEmpty) _addLog(msg, error: isErr);
        break;

      case 'ready':
        _addLog('✅ silnik gotowy (v${ev['version']}, słów: ${ev['dictSize']})');
        break;

      case 'idle':
        break;

      default:
        break;
    }
  }

  void _maybeEnforceWordLimit() {
    final limit = context.read<SettingsProvider>().s.maxWords;
    if (limit > 0 && _answered >= limit && _status == BotStatus.running) {
      _controller?.evaluateJavascript(source: BotConfig.stop);
      setState(() {
        _status = BotStatus.idle;
        _hint = tr(context).lessonMaxWords(limit);
      });
      _addLog(tr(context).lessonMaxWords(limit));
    }
  }

  Future<void> _onSessionEnd(Map<String, dynamic>? stats) async {
    final answered = stats?['answered'] as int? ?? _answered;
    final t = tr(context);
    setState(() {
      _status = BotStatus.finished;
      _answered = answered;
    });
    await context.read<AccountsProvider>().recordSession(_sessionNewWords);
    _addLog('🎉 ${t.lessonFinished}');
  }

  // ---------- sterowanie ----------

  Future<void> _start() async {
    final t = tr(context);
    _userStarted = true;
    _hint = null;
    await _injectEngine();
    await _controller?.evaluateJavascript(source: BotConfig.start);
    if (!mounted) return;
    setState(() => _status = BotStatus.running);
    _addLog('▶ ${t.lessonStart}');
  }

  Future<void> _pause() async {
    final t = tr(context);
    await _controller?.evaluateJavascript(source: BotConfig.pause);
    if (!mounted) return;
    setState(() => _status = BotStatus.paused);
    _addLog('⏸ ${t.lessonPause}');
  }

  Future<void> _resume() async {
    final t = tr(context);
    await _injectEngine();
    await _controller?.evaluateJavascript(source: BotConfig.resume);
    if (!mounted) return;
    setState(() => _status = BotStatus.running);
    _addLog('▶ ${t.lessonResume}');
  }

  Future<void> _stop() async {
    final t = tr(context);
    _userStarted = false;
    await _controller?.evaluateJavascript(source: BotConfig.stop);
    if (!mounted) return;
    setState(() => _status = BotStatus.idle);
    _addLog('⏹ ${t.lessonStop}');
  }

  // ---------- budowa ekranu ----------

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().s;
    final account = context.watch<AccountsProvider>().active;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context).lessonTitle),
        actions: [
          IconButton(
            tooltip: tr(context).lessonLog,
            icon: Icon(
              _showLog ? Icons.playlist_remove : Icons.playlist_add_check,
            ),
            onPressed: () => setState(() => _showLog = !_showLog),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_engineJs == null)
            const LinearProgressIndicator()
          else
            Expanded(
              flex: _showLog ? 3 : 7,
              child: FutureBuilder<void>(
                future: _cookiesReady,
                builder: (context, snapshot) => InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(account?.panelUrl ??
                        'https://instaling.pl/login'),
                  ),
                  initialSettings: InAppWebViewSettings(
                    incognito: settings.incognito,
                    userAgent: settings.userAgent.isEmpty
                        ? null
                        : settings.userAgent,
                    useShouldOverrideUrlLoading: false,
                    mediaPlaybackRequiresUserGesture: false,
                    javaScriptEnabled: true,
                    transparentBackground: false,
                  ),
                  onWebViewCreated: (c) {
                    _controller = c;
                    c.addJavaScriptHandler(
                      handlerName: 'lpBotEvent',
                      callback: _onBotEvent,
                    );
                  },
                  onLoadStop: (c, url) async {
                    if (!mounted) return;
                    final autoStart =
                        context.read<SettingsProvider>().s.autoStart;
                    await _capturePanelUrl(url?.toString());
                    if (!mounted) return;
                    await _injectEngine();
                    if (!mounted) return;
                    if (autoStart && !_userStarted && _status == BotStatus.idle) {
                      await c.evaluateJavascript(source: BotConfig.start);
                      if (!mounted) return;
                      setState(() => _status = BotStatus.running);
                      _userStarted = true;
                    } else if (_userStarted && _status == BotStatus.running) {
                      // ponowne wejście na stronę – wznawiamy pracę, jeśli trwała
                      await c.evaluateJavascript(source: BotConfig.start);
                    }
                  },
                ),
              ),
            ),
          if (_showLog)
            Expanded(
              flex: 4,
              child: _LogPanel(
                lines: _log,
                onClear: () => setState(() => _log.clear()),
              ),
            ),
          _ControlBar(
            status: _status,
            answered: _answered,
            newWords: _sessionNewWords,
            accountName: account?.name,
            onStart: _start,
            onPause: _pause,
            onResume: _resume,
            onStop: _stop,
          ),
          if (_hint != null)
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_hint!, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  final BotStatus status;
  final int answered;
  final int newWords;
  final String? accountName;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _ControlBar({
    required this.status,
    required this.answered,
    required this.newWords,
    required this.accountName,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final scheme = Theme.of(context).colorScheme;

    final (statusLabel, statusColor, statusIcon) = switch (status) {
      BotStatus.running => (t.lessonRunning, scheme.primary, Icons.play_circle),
      BotStatus.paused => (t.lessonPaused, scheme.tertiary, Icons.pause_circle),
      BotStatus.finished =>
        (t.lessonFinished, scheme.tertiary, Icons.celebration_outlined),
      BotStatus.idle => (t.lessonStopped, scheme.outline, Icons.stop_circle_outlined),
    };

    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (accountName != null) ...[
                    Icon(Icons.person_outline,
                        size: 14, color: scheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      accountName!,
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    t.lessonAnswered(answered),
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t.lessonNewWords(newWords),
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.smart_toy_outlined),
                      label: Text(status == BotStatus.paused
                          ? t.lessonResume
                          : t.lessonStart),
                      onPressed: status == BotStatus.running ? onPause : (status == BotStatus.paused ? onResume : onStart),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: status == BotStatus.idle ? null : onStop,
                    child: Text(t.lessonStop),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  final List<_LogLine> lines;
  final VoidCallback onClear;
  const _LogPanel({required this.lines, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
            child: Row(
              children: [
                Text(t.lessonLog,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(onPressed: onClear, child: Text(t.lessonClearLog)),
              ],
            ),
          ),
          Expanded(
            child: lines.isEmpty
                ? Center(
                    child: Text('–',
                        style: TextStyle(color: scheme.outline, fontSize: 20)))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: lines.length,
                    itemBuilder: (context, i) {
                      final line = lines[lines.length - 1 - i];
                      final time =
                          '${line.ts.hour.toString().padLeft(2, '0')}:${line.ts.minute.toString().padLeft(2, '0')}:${line.ts.second.toString().padLeft(2, '0')}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '$time  ${line.text}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: line.error
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
