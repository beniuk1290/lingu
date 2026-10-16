import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Codzienne przypomnienia o nauce (działa bez otwierania aplikacji).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(const InitializationSettings(
      android: android,
      iOS: ios,
    ));

    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
    }
    _ready = true;
  }

  static const _channel = AndroidNotificationDetails(
    'lp_reminders',
    'Przypomnienia o nauce',
    channelDescription: 'Codzienne przypomnienia o sesji InstaLing',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  static tz.TZDateTime _nextInstanceOf(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 18;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static const _details =
      NotificationDetails(android: _channel, iOS: DarwinNotificationDetails());

  /// Ustawia (lub wygasza) przypomnienia zgodnie z ustawieniami.
  Future<void> apply({
    required bool enabled,
    required String reminder1,
    String? reminder2,
  }) async {
    await cancel();
    if (!enabled) return;
    await _plugin.zonedSchedule(
      1,
      'Pora na InstaLing 📚',
      'Kilka słówek dziennie i język stoi otworem. Uruchom LingoPilot!',
      _nextInstanceOf(reminder1),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    if (reminder2 != null && reminder2.isNotEmpty) {
      await _plugin.zonedSchedule(
        2,
        'Pora na InstaLing 📚',
        'Kilka słówek dziennie i język stoi otworem. Uruchom LingoPilot!',
        _nextInstanceOf(reminder2),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancel() async {
    await _plugin.cancelAll();
  }
}
