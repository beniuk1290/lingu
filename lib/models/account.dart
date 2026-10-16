import 'dart:convert';

/// Konto InstaLing (maks. 2) wraz ze statystykami i zapasem ciasteczek.
class Account {
  final String id;
  String name;
  final int createdAt;
  int sessions;
  int wordsLearned;
  String? lastSessionDate; // 'yyyy-MM-dd'
  int streak;
  /// Zapisane ciasteczka sesji instaling.pl (mapa nazwa → wartość).
  Map<String, String> cookies;

  /// Zapamiętany adres panelu ucznia (mainPage.php?student_id=...).
  /// Serwer nadaje ten adres po zalogowaniu; dzięki niemu lekcja startuje
  /// od razu we właściwym miejscu zamiast na stronie logowania.
  String? panelUrl;

  Account({
    required this.id,
    required this.name,
    required this.createdAt,
    this.sessions = 0,
    this.wordsLearned = 0,
    this.lastSessionDate,
    this.streak = 0,
    this.panelUrl,
    Map<String, String>? cookies,
  }) : cookies = cookies ?? {};

  /// Aktualizuje statystyki po zakończonej sesji (dzienna seria).
  void recordSession(int newWords, DateTime today) {
    final day = _dayKey(today);
    if (lastSessionDate == day) return; // już policzone dzisiaj
    final yesterday = _dayKey(today.subtract(const Duration(days: 1)));
    streak = (lastSessionDate == yesterday) ? streak + 1 : 1;
    lastSessionDate = day;
    sessions += 1;
    wordsLearned += newWords;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Dzisiejsza sesja już wykonana?
  bool get doneToday => lastSessionDate == _dayKey(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt,
        'sessions': sessions,
        'wordsLearned': wordsLearned,
        'lastSessionDate': lastSessionDate,
        'streak': streak,
        'panelUrl': panelUrl,
        'cookies': cookies,
      };

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String? ?? 'Konto',
        createdAt: (m['createdAt'] as num?)?.toInt() ?? 0,
        sessions: (m['sessions'] as num?)?.toInt() ?? 0,
        wordsLearned: (m['wordsLearned'] as num?)?.toInt() ?? 0,
        lastSessionDate: m['lastSessionDate'] as String?,
        streak: (m['streak'] as num?)?.toInt() ?? 0,
        panelUrl: m['panelUrl'] as String?,
        cookies: ((m['cookies'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );

  String toJson() => jsonEncode(toMap());
  factory Account.fromJson(String s) =>
      Account.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
