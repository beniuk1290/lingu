import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/models/account.dart';
import 'package:linguapilot/providers/accounts_provider.dart';
import 'package:linguapilot/providers/settings_provider.dart';
import 'package:linguapilot/services/cookie_vault.dart';
import 'package:provider/provider.dart';

/// Prosta przeglądarka do ręcznego zalogowania się w InstaLing.
/// Ciasteczka trafiają do pamięci WebView; aplikacja NIE zapisuje hasła.
///
/// Ekran jest powiązany z KONKRETNYM kontem ([account]) – dzięki temu
/// logując się na drugie konto, nie nadpisujemy ciasteczek pierwszego.
class LoginWebViewScreen extends StatefulWidget {
  /// Konto, dla którego zapisujemy sesję. Domyślnie aktywne konto.
  final Account? account;

  const LoginWebViewScreen({super.key, this.account});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  double _progress = 0;

  /// Ciasteczka docelowego konta podmieniamy dokładnie raz, przed pierwszym
  /// załadowaniem (Future przechowywany, żeby przebudowy ekranu go nie
  /// przeliczały).
  late final Future<void> _cookiesReady = _prepareCookies();

  Future<void> _prepareCookies() async {
    final target = widget.account ??
        context.read<AccountsProvider>().active;
    if (target == null) return;
    await CookieVault.replaceWith(target.cookies);
  }

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final settings = context.watch<SettingsProvider>().s;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.obLoginTitle),
        actions: [
          TextButton(
            onPressed: () => _finish(),
            child: Text(t.done,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress > 0 && _progress < 1)
            LinearProgressIndicator(value: _progress),
          Expanded(
            child: FutureBuilder<void>(
              future: _cookiesReady,
              builder: (context, snapshot) => InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://instaling.pl/login'),
                ),
                initialSettings: InAppWebViewSettings(
                  incognito: settings.incognito,
                  userAgent:
                      settings.userAgent.isEmpty ? null : settings.userAgent,
                  useShouldOverrideUrlLoading: false,
                  javaScriptEnabled: true,
                ),
                onProgressChanged: (c, p) =>
                    setState(() => _progress = p / 100),
                onLoadStop: (c, url) => _capturePanelUrl(url?.toString()),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text(t.obLoginDone),
                  onPressed: () => _finish(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Konto, którego dotyczy to logowanie.
  Account? _target() => widget.account ?? context.read<AccountsProvider>().active;

  Future<void> _finish() async {
    final provider = context.read<AccountsProvider>();
    final target = widget.account ?? provider.active;
    if (target != null) {
      final map = await CookieVault.read();
      if (map.isNotEmpty) {
        await provider.saveCookies(target, map);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Po zalogowaniu serwer przekierowuje ucznia na
  /// mainPage.php?student_id=N – zapamiętujemy ten adres dla lekcji.
  Future<void> _capturePanelUrl(String? url) async {
    if (url == null) return;
    final isPanel = RegExp(r'mainPage\.php\?student_id=\d+').hasMatch(url) ||
        url.contains('html_app/app.php?');
    if (!isPanel) return;
    final target = _target();
    if (target == null || !mounted) return;
    await context.read<AccountsProvider>().savePanelUrl(target, url);
  }
}
