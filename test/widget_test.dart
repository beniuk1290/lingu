import 'package:flutter_test/flutter_test.dart';
import 'package:linguapilot/models/app_settings.dart';

void main() {
  test('aplikacja posiada sensowne ustawienia domyślne', () {
    expect(AppSettings.defaults.lessonLang, 'en');
    expect(AppSettings.defaults.autoStart, isTrue);
  });
}
