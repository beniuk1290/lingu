import 'dart:convert';

/// Pojedyncze słówko w trwałym słowniczku.
class DictEntry {
  final String lang; // język lekcji, np. en
  final String src; // słowo / pytanie pokazywane przez InstaLing
  final String dst; // tłumaczenie / poprawna odpowiedź
  final int hits; // ile razy słówko zostało wykorzystane
  final int addedAt; // epoch ms

  const DictEntry({
    required this.lang,
    required this.src,
    required this.dst,
    this.hits = 0,
    required this.addedAt,
  });

  /// Klucz unikalny: jedno tłumaczenie na pytanie w danym języku.
  static String keyFor(String lang, String src) =>
      '$lang|${src.trim().toLowerCase()}';

  String get key => keyFor(lang, src);

  DictEntry copyWith({String? src, String? dst, int? hits}) => DictEntry(
        lang: lang,
        src: src ?? this.src,
        dst: dst ?? this.dst,
        hits: hits ?? this.hits,
        addedAt: addedAt,
      );

  Map<String, dynamic> toMap() => {
        'lang': lang,
        'src': src,
        'dst': dst,
        'hits': hits,
        'addedAt': addedAt,
      };

  factory DictEntry.fromMap(Map<String, dynamic> m) => DictEntry(
        lang: m['lang'] as String? ?? 'en',
        src: m['src'] as String? ?? '',
        dst: m['dst'] as String? ?? '',
        hits: (m['hits'] as num?)?.toInt() ?? 0,
        addedAt: (m['addedAt'] as num?)?.toInt() ?? 0,
      );

  String toJson() => jsonEncode(toMap());
  factory DictEntry.fromJson(String s) =>
      DictEntry.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
