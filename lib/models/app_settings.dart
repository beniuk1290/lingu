import 'dart:convert';

/// Ustawienia aplikacji (trwałe, w Hive).
class AppSettings {
  final String themeMode; // system | light | dark
  final String accentId;
  final String? appLocale; // null = jak w systemie
  final String lessonLang; // en, de, es, fr...
  final String speedPreset; // slow | normal | fast | custom
  final int typingMin;
  final int typingMax;
  final int typoRatePct; // 0–15 (%)
  final int wordDelay; // ms – bazowa przerwa między słowami
  final int tickDelay; // ms – bazowy czas reakcji na pytanie
  final int errorRatePct; // 0–30 (%)
  final int maxWords; // 0 = bez limitu
  final bool autoStart;
  final bool autoLearn;
  final bool debugLog;
  final bool incognito;
  final String userAgent;
  final bool remindersEnabled;
  final String reminder1; // "HH:mm"
  final String? reminder2; // "HH:mm" lub null
  final bool backgroundSession; // sesja w tle + powiadomienie ze statystykami

  static const defaults = AppSettings(
    themeMode: 'system',
    accentId: 'indigo',
    appLocale: null,
    lessonLang: 'en',
    speedPreset: 'normal',
    typingMin: 45,
    typingMax: 140,
    typoRatePct: 3,
    wordDelay: 800,
    tickDelay: 900,
    errorRatePct: 0,
    maxWords: 0,
    autoStart: true,
    autoLearn: true,
    debugLog: false,
    incognito: true,
    userAgent: '',
    remindersEnabled: false,
    reminder1: '18:00',
    reminder2: null,
    backgroundSession: false,
  );

  const AppSettings({
    required this.themeMode,
    required this.accentId,
    required this.appLocale,
    required this.lessonLang,
    required this.speedPreset,
    required this.typingMin,
    required this.typingMax,
    required this.typoRatePct,
    required this.wordDelay,
    required this.tickDelay,
    required this.errorRatePct,
    required this.maxWords,
    required this.autoStart,
    required this.autoLearn,
    required this.debugLog,
    required this.incognito,
    required this.userAgent,
    required this.remindersEnabled,
    required this.reminder1,
    required this.reminder2,
    required this.backgroundSession,
  });

  AppSettings copyWith({
    String? themeMode,
    String? accentId,
    String? appLocale,
    String? lessonLang,
    String? speedPreset,
    int? typingMin,
    int? typingMax,
    int? typoRatePct,
    int? wordDelay,
    int? tickDelay,
    int? errorRatePct,
    int? maxWords,
    bool? autoStart,
    bool? autoLearn,
    bool? debugLog,
    bool? incognito,
    String? userAgent,
    bool? remindersEnabled,
    String? reminder1,
    String? reminder2,
    bool? backgroundSession,
    bool clearAppLocale = false,
    bool clearReminder2 = false,
    bool clearUserAgent = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentId: accentId ?? this.accentId,
      appLocale: clearAppLocale ? null : (appLocale ?? this.appLocale),
      lessonLang: lessonLang ?? this.lessonLang,
      speedPreset: speedPreset ?? this.speedPreset,
      typingMin: typingMin ?? this.typingMin,
      typingMax: typingMax ?? this.typingMax,
      typoRatePct: typoRatePct ?? this.typoRatePct,
      wordDelay: wordDelay ?? this.wordDelay,
      tickDelay: tickDelay ?? this.tickDelay,
      errorRatePct: errorRatePct ?? this.errorRatePct,
      maxWords: maxWords ?? this.maxWords,
      autoStart: autoStart ?? this.autoStart,
      autoLearn: autoLearn ?? this.autoLearn,
      debugLog: debugLog ?? this.debugLog,
      incognito: incognito ?? this.incognito,
      userAgent: clearUserAgent ? '' : (userAgent ?? this.userAgent),
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminder1: reminder1 ?? this.reminder1,
      reminder2: clearReminder2 ? null : (reminder2 ?? this.reminder2),
      backgroundSession: backgroundSession ?? this.backgroundSession,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode,
        'accentId': accentId,
        'appLocale': appLocale,
        'lessonLang': lessonLang,
        'speedPreset': speedPreset,
        'typingMin': typingMin,
        'typingMax': typingMax,
        'typoRatePct': typoRatePct,
        'wordDelay': wordDelay,
        'tickDelay': tickDelay,
        'errorRatePct': errorRatePct,
        'maxWords': maxWords,
        'autoStart': autoStart,
        'autoLearn': autoLearn,
        'debugLog': debugLog,
        'incognito': incognito,
        'userAgent': userAgent,
        'remindersEnabled': remindersEnabled,
        'reminder1': reminder1,
        'reminder2': reminder2,
        'backgroundSession': backgroundSession,
      };

  factory AppSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    final d = defaults;
    return AppSettings(
      themeMode: m['themeMode'] as String? ?? d.themeMode,
      accentId: m['accentId'] as String? ?? d.accentId,
      appLocale: m['appLocale'] as String?,
      lessonLang: m['lessonLang'] as String? ?? d.lessonLang,
      speedPreset: m['speedPreset'] as String? ?? d.speedPreset,
      typingMin: (m['typingMin'] as num?)?.toInt() ?? d.typingMin,
      typingMax: (m['typingMax'] as num?)?.toInt() ?? d.typingMax,
      typoRatePct: (m['typoRatePct'] as num?)?.toInt() ?? d.typoRatePct,
      wordDelay: (m['wordDelay'] as num?)?.toInt() ?? d.wordDelay,
      tickDelay: (m['tickDelay'] as num?)?.toInt() ?? d.tickDelay,
      errorRatePct: (m['errorRatePct'] as num?)?.toInt() ?? d.errorRatePct,
      maxWords: (m['maxWords'] as num?)?.toInt() ?? d.maxWords,
      autoStart: m['autoStart'] as bool? ?? d.autoStart,
      autoLearn: m['autoLearn'] as bool? ?? d.autoLearn,
      debugLog: m['debugLog'] as bool? ?? d.debugLog,
      incognito: m['incognito'] as bool? ?? d.incognito,
      userAgent: m['userAgent'] as String? ?? '',
      remindersEnabled: m['remindersEnabled'] as bool? ?? d.remindersEnabled,
      reminder1: m['reminder1'] as String? ?? d.reminder1,
      reminder2: m['reminder2'] as String?,
      backgroundSession: m['backgroundSession'] as bool? ?? d.backgroundSession,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory AppSettings.fromJson(String s) =>
      AppSettings.fromMap(jsonDecode(s) as Map<String, dynamic>);

  /// Faktyczne opóźnienia pisania wynikające z presetu / trybu custom.
  ({int min, int max}) get effectiveTyping {
    switch (speedPreset) {
      case 'slow':
        return (min: 90, max: 190);
      case 'fast':
        return (min: 25, max: 75);
      case 'custom':
        return (min: typingMin, max: typingMax);
      case 'normal':
      default:
        return (min: 45, max: 140);
    }
  }
}
