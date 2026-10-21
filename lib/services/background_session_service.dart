import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/account.dart';
import '../models/app_settings.dart';
import '../models/dict_entry.dart';
import 'bot_config.dart';
import 'cookie_vault.dart';
import 'storage_service.dart';

/// Sesja w tle: usługa systemowa (foreground service) z ukrytą stroną
/// WebView (headless), która rozwiązuje sesję InstaLing poza ekranem aplikacji.
///
/// Po zakończeniu (lub problemie) użytkownik dostaje powiadomienie
/// ze statystykami sesji. Android-only – na iOS system zawiesza aplikację
/// w tle, więc funkcja jest ukryta w interfejsie.
class BackgroundSessionService {
  BackgroundSessionService._();

  static const channelId = 'lp_background';
  static const channelName = 'Sesja w tle';
  static const foregroundNotificationId = 888;
  static const _resultNotificationId = 10;

  /// Bezpieczny margines – sesja InstaLing nigdy nie trwa dłużej.
  static const _maxDuration = Duration(minutes: 25);

  static Future<bool> isRunning() async {
    try {
      return await FlutterBackgroundService().isRunning();
    } catch (_) {
      return false;
    }
  }

  /// Wywoływana raz przy starcie aplikacji (main()).
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: 'LingoPilot – sesja w tle',
        initialNotificationContent: 'Bot rozwiązuje sesję…',
        foregroundServiceNotificationId: foregroundNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );
  }

  /// Start sesji w tle (wywoływane z UI, gdy użytkownik jest na ekranie).
  static Future<void> start() => FlutterBackgroundService().startService();

  /// Zatrzymanie sesji w tle z poziomu aplikacji.
  static void stop() => FlutterBackgroundService().invoke('stop');

  // ----------------------------------------------------------------- silnik

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    HeadlessInAppWebView? web;
    Timer? watchdog;
    var answered = 0;
    var newWords = 0;
    var finished = false;
    final learned = <String, String>{}; // "lang|src" -> dst

    Future<void> finish(String title, String body,
        {bool recordSession = false}) async {
      if (finished) return;
      finished = true;
      watchdog?.cancel();
      try {
        await web?.dispose();
      } catch (_) {}
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      if (recordSession) {
        await _recordStats(newWords);
      }
      await _flushDictionary(learned);
      await _notify(title, body);
      try {
        await service.stopSelf();
      } catch (_) {
        // usługa już zatrzymana
      }
    }

    service.on('stop').listen((_) {
      unawaited(finish('⏹ Sesja w tle zatrzymana',
          'Zatrzymano przez użytkownika. Odpowiedzi: $answered.'));
    });

    try {
      await StorageService.init();

      var settings = AppSettings.defaults;
      try {
        final raw = StorageService.settings.get('app');
        if (raw != null) settings = AppSettings.fromJson(raw);
      } catch (_) {}

      final account = _findActiveAccount();
      if (account == null) {
        await finish('⚠️ Sesja w tle – brak konta',
            'Otwórz aplikację i skonfiguruj konto InstaLing.');
        return;
      }

      await CookieVault.replaceWith(account.cookies);
      try {
        await WakelockPlus.enable();
      } catch (_) {}

      final lang = settings.lessonLang;
      final engineJs =
          await rootBundle.loadString('assets/js/instaling_bot.js');
      final botDict = _loadBotDict(lang);
      final config = BotConfig.build(
          settings: settings, dictionary: botDict, lang: lang);

      final startUrl = account.panelUrl ?? 'https://instaling.pl/login';

      web = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(startUrl)),
        initialSettings: InAppWebViewSettings(
          incognito: settings.incognito,
          userAgent: settings.userAgent.isEmpty ? null : settings.userAgent,
          useShouldOverrideUrlLoading: false,
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (c) {
          c.addJavaScriptHandler(
            handlerName: 'lpBotEvent',
            callback: (args) {
              if (finished || args.isEmpty) return;
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
                case 'progress':
                  answered = stats?['answered'] as int? ?? answered;
                  break;
                case 'word':
                  final wLang = ev['lang'] as String? ?? lang;
                  final src = (ev['src'] as String? ?? '').trim();
                  final dst = (ev['dst'] as String? ?? '').trim();
                  if (src.isNotEmpty && dst.isNotEmpty) {
                    learned['$wLang|$src'] = dst;
                    newWords++;
                  }
                  break;
                case 'sessionEnd':
                  unawaited(finish(
                    '✅ Sesja w tle ukończona 📚',
                    'Odpowiedzi: $answered, nowych słówek: $newWords. '
                        'Statystyki zapisane w aplikacji.',
                    recordSession: true,
                  ));
                  break;
                case 'loginRequired':
                  unawaited(finish(
                      '🔒 Sesja w tle wymaga logowania',
                      'Otwórz LingoPilot i zaloguj się ponownie w Kontach.'));
                  break;
                default:
                  break;
              }
            },
          );
        },
        onLoadStop: (c, url) async {
          if (finished) return;
          try {
            await c.evaluateJavascript(source: engineJs);
            await c.evaluateJavascript(source: config);
            // start przy pierwszym załadowaniu, wznowienie przy kolejnych
            await c.evaluateJavascript(source: BotConfig.start);
          } catch (_) {
            // strona się zmieni – spróbujemy przy następnym onLoadStop
          }
        },
      );

      // ignore: discarded_futures
      web.run();
      watchdog = Timer(_maxDuration, () {
        unawaited(finish(
          '⏱ Sesja w tle – limit czasu',
          'Sesja nie zakończyła się w $answered odpowiedziach w 25 minut. '
              'Sprawdź aplikację.',
        ));
      });
    } catch (e) {
      await finish('⚠️ Sesja w tle – błąd',
          'Nie udało się uruchomić sesji: ${e.toString().split('\n').first}');
    }
  }

  // ------------------------------------------------------------ pomocnicze

  static Account? _findActiveAccount() {
    final activeId = StorageService.activeAccountId;
    Account? fallback;
    for (final key in StorageService.accounts.keys) {
      final raw = StorageService.accounts.get(key);
      if (raw == null) continue;
      try {
        final a = Account.fromJson(raw);
        if (a.id == activeId) return a;
        fallback ??= a;
      } catch (_) {
        // uszkodzony rekord pomijamy
      }
    }
    return fallback;
  }

  /// Słownik w formacie bota {pytanie: odpowiedź} dla danego języka.
  static Map<String, String> _loadBotDict(String lang) {
    final out = <String, String>{};
    for (final key in StorageService.dictionary.keys) {
      final raw = StorageService.dictionary.get(key);
      if (raw == null) continue;
      try {
        final e = DictEntry.fromJson(raw);
        if (e.lang == lang) out[e.src] = e.dst;
      } catch (_) {}
    }
    return out;
  }

  /// Zapisuje odsłonięte tłumaczenia do trwałego słowniczka (batch na koniec).
  static Future<void> _flushDictionary(Map<String, String> learned) async {
    for (final entry in learned.entries) {
      final sep = entry.key.indexOf('|');
      if (sep < 0) continue;
      final lang = entry.key.substring(0, sep);
      final src = entry.key.substring(sep + 1).trim();
      final dst = entry.value.trim();
      if (src.isEmpty || dst.isEmpty || src == dst) continue;
      final key = DictEntry.keyFor(lang, src);
      DictEntry? existing;
      try {
        final raw = StorageService.dictionary.get(key);
        if (raw != null) existing = DictEntry.fromJson(raw);
      } catch (_) {}
      if (existing != null && existing.dst == dst) continue;
      final next = (existing == null)
          ? DictEntry(
              lang: lang,
              src: src,
              dst: dst,
              addedAt: DateTime.now().millisecondsSinceEpoch)
          : existing.copyWith(dst: dst);
      await StorageService.dictionary.put(key, next.toJson());
    }
  }

  /// Aktualizuje statystyki aktywnego konta (sesja + seria + słowa).
  static Future<void> _recordStats(int newWords) async {
    final account = _findActiveAccount();
    if (account == null) return;
    // ponowny odczyt z dysku – na wypadek, gdyby UI zapisało coś po drodze
    var fresh = account;
    final raw = StorageService.accounts.get(account.id);
    if (raw != null) {
      try {
        fresh = Account.fromJson(raw);
      } catch (_) {}
    }
    fresh.recordSession(newWords, DateTime.now());
    await StorageService.accounts.put(fresh.id, fresh.toJson());
  }

  static Future<void> _notify(String title, String body) async {
    const android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Powiadomienia o sesji rozwiązywanej w tle',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_bg_service_small',
    );
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    await plugin.show(
      _resultNotificationId,
      title,
      body,
      const NotificationDetails(
          android: android, iOS: DarwinNotificationDetails()),
    );
  }
}
