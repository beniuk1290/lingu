import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  AppSettings _s = AppSettings.defaults;
  AppSettings get s => _s;

  void load() {
    final raw = StorageService.settings.get('app');
    if (raw != null) {
      try {
        _s = AppSettings.fromJson(raw);
      } catch (_) {
        _s = AppSettings.defaults;
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await StorageService.settings.put('app', _s.toJson());
  }

  Future<void> update(AppSettings next) async {
    _s = next;
    notifyListeners();
    await _persist();
    await _applyNotifications();
  }

  Future<void> reset() async {
    _s = AppSettings.defaults.copyWith(
      // zachowaj to, co użytkownik już skonfigurował poza botem
      remindersEnabled: _s.remindersEnabled,
      reminder1: _s.reminder1,
      reminder2: _s.reminder2,
    );
    notifyListeners();
    await _persist();
    await _applyNotifications();
  }

  Future<void> _applyNotifications() async {
    try {
      await NotificationService.instance.apply(
        enabled: _s.remindersEnabled,
        reminder1: _s.reminder1,
        reminder2: _s.reminder2,
      );
    } catch (_) {
      // brak uprawnień / kanału – użytkownik zobaczy to przy ręcznym włączeniu
    }
  }

  ThemeMode get themeMode => switch (_s.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Locale? get locale => _s.appLocale == null ? null : Locale(_s.appLocale!);
}
