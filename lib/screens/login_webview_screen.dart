import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/providers/accounts_provider.dart';
import 'package:linguapilot/providers/settings_provider.dart';
import 'package:linguapilot/screens/accounts_screen.dart';
import 'package:provider/provider.dart';

/// Prosta przeglądarka do ręcznego zalogowania się w InstaLing.
/// Ciasteczka trafiają do pamięci WebView; aplikacja NIE zapisuje hasła.
class LoginWebViewScreen extends StatefulWidget {
  const LoginWebViewScreen({super.key});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  double _progress = 0;

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
              future: restoreCookiesFor(
                  context.read<AccountsProvider>().active!),
              builder: (context, snapshot) => InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://instaling.pl/teacher/login.html'),
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

  Future<void> _finish() async {
    final provider = context.read<AccountsProvider>();
    final active = provider.active;
    if (active != null) {
      try {
        final cm = CookieManager.instance();
        final cookies =
            await cm.getCookies(url: WebUri(kInstaLingOrigin));
        final map = <String, String>{};
        for (final c in cookies) {
          map[c.name] = c.value;
        }
        await provider.saveCookies(active, map);
      } catch (_) {
        // brak WebView – pomijamy
      }
    }
    if (mounted) Navigator.of(context).pop();
  }
}
