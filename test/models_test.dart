import 'package:flutter_test/flutter_test.dart';
import 'package:linguapilot/models/account.dart';
import 'package:linguapilot/models/app_settings.dart';
import 'package:linguapilot/models/dict_entry.dart';

void main() {
  group('AppSettings', () {
    test('domyślne wartości są sensowne', () {
      final s = AppSettings.defaults;
      expect(s.lessonLang, 'en');
      expect(s.speedPreset, 'normal');
      expect(s.autoStart, isTrue);
      expect(s.remindersEnabled, isFalse);
    });

    test('copyWith zmienia tylko wskazane pola', () {
      final s = AppSettings.defaults.copyWith(lessonLang: 'de');
      expect(s.lessonLang, 'de');
      expect(s.themeMode, AppSettings.defaults.themeMode);
    });

    test('serializacja json przechodzi round-trip', () {
      final s = AppSettings.defaults.copyWith(
        lessonLang: 'de',
        typingMin: 50,
        remindersEnabled: true,
        reminder2: '20:30',
      );
      final restored = AppSettings.fromJson(s.toJson());
      expect(restored.lessonLang, 'de');
      expect(restored.typingMin, 50);
      expect(restored.remindersEnabled, isTrue);
      expect(restored.reminder2, '20:30');
    });

    test('preset szybki pisze szybciej niż spokojny', () {
      final fast =
          AppSettings.defaults.copyWith(speedPreset: 'fast').effectiveTyping;
      final slow =
          AppSettings.defaults.copyWith(speedPreset: 'slow').effectiveTyping;
      expect(fast.min, lessThan(slow.min));
    });
  });

  group('DictEntry', () {
    test('klucz jest unikalny i niezależny od wielkości liter', () {
      final a = DictEntry.keyFor('en', 'Dog');
      final b = DictEntry.keyFor('en', 'dog');
      expect(a, b);
      expect(DictEntry.keyFor('de', 'dog'), isNot(a));
    });

    test('serializacja round-trip', () {
      final e = DictEntry(lang: 'en', src: 'cat', dst: 'kot', addedAt: 1);
      final restored = DictEntry.fromJson(e.toJson());
      expect(restored.src, 'cat');
      expect(restored.dst, 'kot');
      expect(restored.lang, 'en');
    });
  });

  group('Account', () {
    test('recordSession buduje dzienną serię', () {
      final a = Account(id: '1', name: 'Test', createdAt: 0);
      final day1 = DateTime(2026, 10, 1, 12);
      final day2 = DateTime(2026, 10, 2, 12);

      a.recordSession(5, day1);
      expect(a.streak, 1);
      expect(a.sessions, 1);
      expect(a.wordsLearned, 5);

      // druga sesja tego samego dnia nie zmienia serii
      a.recordSession(3, day1);
      expect(a.streak, 1);
      expect(a.sessions, 1);

      // sesja następnego dnia wydłuża serię
      a.recordSession(2, day2);
      expect(a.streak, 2);
      expect(a.sessions, 2);
      expect(a.wordsLearned, 7);
    });

    test('seria zrywa się po przerwie', () {
      final a = Account(id: '1', name: 'Test', createdAt: 0);
      a.recordSession(1, DateTime(2026, 10, 1));
      a.recordSession(1, DateTime(2026, 10, 5));
      expect(a.streak, 1);
    });

    test('serializacja round-trip', () {
      final a = Account(id: '1', name: 'Ania', createdAt: 42);
      a.sessions = 3;
      a.cookies = {'sessionid': 'abc'};
      final restored = Account.fromJson(a.toJson());
      expect(restored.name, 'Ania');
      expect(restored.sessions, 3);
      expect(restored.cookies['sessionid'], 'abc');
    });
  });
}
