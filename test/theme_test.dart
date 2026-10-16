import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguapilot/theme/app_theme.dart';

void main() {
  testWidgets('motyw buduje się bez błędów', (tester) async {
    final light = AppTheme.light(const Color(0xFF3F51B5));
    final dark = AppTheme.dark(const Color(0xFF3F51B5));
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, isNotNull);
  });

  test('accentById zwraca kolory dla znanych id', () {
    expect(accentById('teal'), const Color(0xFF00897B));
    expect(accentById('nieznany'), accentById('indigo'));
  });
}
