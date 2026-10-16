import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/app_settings.dart';

/// Buduje konfigurację bota na podstawie ustawień użytkownika
/// i wczytuje skrypt silnika z assets.
class BotConfig {
  static Future<String> get engineScript =>
      rootBundle.loadString('assets/js/instaling_bot.js');

  /// JSON konfiguracji zgodny z window.__lpBot.configure(...) w JS.
  static String build({
    required AppSettings settings,
    required Map<String, String> dictionary,
    required String lang,
  }) {
    final typing = settings.effectiveTyping;
    return jsonEncode({
      'lang': lang,
      'dict': dictionary,
      'autoLearn': settings.autoLearn,
      'debug': settings.debugLog,
      'errorRate': settings.errorRatePct / 100.0,
      'typing': {
        'min': typing.min,
        'max': typing.max,
        'thinkMin': 250,
        'thinkMax': 1100,
        'typoRate': settings.typoRatePct / 100.0,
      },
      'delays': {
        'tickMin': settings.tickDelay,
        'tickMax': (settings.tickDelay * 1.9).round(),
        'clickMin': 280,
        'clickMax': 900,
        'wordMin': settings.wordDelay,
        'wordMax': (settings.wordDelay * 2.4).round(),
      },
    });
  }

  /// Wywołania JS sterujące botem.
  static const start = 'window.__lpBot && window.__lpBot.start();';
  static const pause = 'window.__lpBot && window.__lpBot.pause();';
  static const resume = 'window.__lpBot && window.__lpBot.resume();';
  static const stop = 'window.__lpBot && window.__lpBot.stop();';
  static const destroy = 'window.__lpBot && window.__lpBot.destroy();';

  static String configure(String configJson) =>
      'window.__lpBot && window.__lpBot.configure(\''
      '${configJson.replaceAll("'", r"\'")}\');';
}
