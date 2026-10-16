import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/accounts_provider.dart';
import 'providers/dictionary_provider.dart';
import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.init();
  await NotificationService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => DictionaryProvider()..load()),
        ChangeNotifierProvider(create: (_) => AccountsProvider()..load()),
      ],
      child: const LingoPilotApp(),
    ),
  );
}
