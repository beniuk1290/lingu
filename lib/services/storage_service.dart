import 'package:hive_flutter/hive_flutter.dart';

/// Trwałe skrzynie Hive – słowniczek nigdy nie znika z pamięci urządzenia.
class StorageService {
  StorageService._();

  static const _settingsBox = 'settings';
  static const _dictionaryBox = 'dictionary';
  static const _accountsBox = 'accounts';
  static const _metaBox = 'meta';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_settingsBox);
    await Hive.openBox<String>(_dictionaryBox);
    await Hive.openBox<String>(_accountsBox);
    await Hive.openBox(_metaBox);
  }

  static Box<String> get settings => Hive.box<String>(_settingsBox);
  static Box<String> get dictionary => Hive.box<String>(_dictionaryBox);
  static Box<String> get accounts => Hive.box<String>(_accountsBox);
  static Box get meta => Hive.box(_metaBox);

  static bool get onboarded => meta.get('onboarded', defaultValue: false) == true;
  static Future<void> setOnboarded() => meta.put('onboarded', true);

  static String? get activeAccountId => meta.get('activeAccountId') as String?;
  static Future<void> setActiveAccountId(String id) =>
      meta.put('activeAccountId', id);
}
