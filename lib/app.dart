import 'package:flutter/material.dart';
import 'package:linguapilot/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

class LingoPilotApp extends StatelessWidget {
  const LingoPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final accent = accentById(settings.s.accentId);

    return MaterialApp(
      title: 'LingoPilot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: StorageService.onboarded
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}
