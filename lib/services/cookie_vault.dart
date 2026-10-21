import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Adres originu InstaLing – jedyna strona odwiedzana przez WebView aplikacji.
const kInstaLingOrigin = 'https://instaling.pl';

/// Centralne miejsce zarządzania ciasteczkami sesji InstaLing.
///
/// Kluczowa zasada: pamięć ciasteczek WebView jest JEDNA na całą aplikację,
/// dlatego przed wstawieniem ciasteczek danego konta zawsze czyścimy całą
/// pamięć (deleteAllCookies). Bez tego sesje dwóch kont mieszały się i po
/// zalogowaniu jednego konta drugie natychmiast „wylogowywało" się.
class CookieVault {
  CookieVault._();

  /// Odczytuje aktualne ciasteczka instaling.pl z pamięci WebView.
  static Future<Map<String, String>> read() async {
    try {
      final cm = CookieManager.instance();
      final cookies = await cm.getCookies(url: WebUri(kInstaLingOrigin));
      return {for (final c in cookies) c.name: c.value};
    } catch (_) {
      return {};
    }
  }

  /// Czyści całą pamięć ciasteczek WebView (aplikacja odwiedza tylko
  /// instaling.pl, więc jest to bezpieczne).
  static Future<void> clear() async {
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (_) {
      // WebView jeszcze nie wystartował – nie ma czego czyścić
    }
  }

  /// Podsadza pamięć ciasteczek EXACTLY zgodnie ze zrzutem konta:
  /// najpierw kompletne czyszczenie, potem wstawienie zapisanych wartości.
  static Future<void> replaceWith(Map<String, String> cookies) async {
    try {
      final cm = CookieManager.instance();
      await cm.deleteAllCookies();
      for (final e in cookies.entries) {
        await cm.setCookie(
          url: WebUri(kInstaLingOrigin),
          name: e.key,
          value: e.value,
          domain: '.instaling.pl',
          path: '/',
        );
      }
    } catch (_) {
      // użytkownik zaloguje się ręcznie – nie blokujemy działania
    }
  }
}
