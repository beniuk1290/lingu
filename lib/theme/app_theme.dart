import 'package:flutter/material.dart';

/// Kolory przewodnie do wyboru w ustawieniach.
class AccentOption {
  final String id;
  final Color color;
  final String labelPl;
  const AccentOption(this.id, this.color, this.labelPl);
}

const kAccentOptions = <AccentOption>[
  AccentOption('indigo', Color(0xFF3F51B5), 'Indygo'),
  AccentOption('teal', Color(0xFF00897B), 'Morski'),
  AccentOption('green', Color(0xFF43A047), 'Zielony'),
  AccentOption('orange', Color(0xFFFB8C00), 'Pomarańczowy'),
  AccentOption('rose', Color(0xFFD81B60), 'Różowy'),
  AccentOption('purple', Color(0xFF8E24AA), 'Fioletowy'),
];

Color accentById(String id) {
  for (final a in kAccentOptions) {
    if (a.id == id) return a.color;
  }
  return kAccentOptions.first.color;
}

class AppTheme {
  static ThemeData light(Color accent) => _base(Brightness.light, accent);
  static ThemeData dark(Color accent) => _base(Brightness.dark, accent);

  static ThemeData _base(Brightness brightness, Color accent) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: rounded,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : null,
        ),
      ),
    );
  }
}
