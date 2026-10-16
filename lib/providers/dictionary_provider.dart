import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/dict_entry.dart';
import '../services/storage_service.dart';

/// Trwały słowniczek – trzymany w Hive, przeżywa restart aplikacji.
class DictionaryProvider extends ChangeNotifier {
  final Map<String, DictEntry> _byKey = {};

  int get length => _byKey.length;

  List<DictEntry> get all {
    final list = _byKey.values.toList()
      ..sort((a, b) => a.src.toLowerCase().compareTo(b.src.toLowerCase()));
    return list;
  }

  List<DictEntry> byLang(String lang) =>
      all.where((e) => e.lang == lang).toList();

  List<DictEntry> search(String query, {String? lang}) {
    final q = query.trim().toLowerCase();
    return all.where((e) {
      if (lang != null && e.lang != lang) return false;
      if (q.isEmpty) return true;
      return e.src.toLowerCase().contains(q) ||
          e.dst.toLowerCase().contains(q);
    }).toList();
  }

  void load() {
    _byKey.clear();
    for (final key in StorageService.dictionary.keys) {
      final raw = StorageService.dictionary.get(key);
      if (raw == null) continue;
      try {
        final e = DictEntry.fromJson(raw);
        _byKey[e.key] = e;
      } catch (_) {
        // uszkodzony rekord pomijamy, reszta słowniczka działa
      }
    }
    notifyListeners();
  }

  Future<void> upsert(String lang, String src, String dst,
      {bool bumpHits = false}) async {
    src = src.trim();
    dst = dst.trim();
    if (src.isEmpty || dst.isEmpty || src == dst) return;
    final key = DictEntry.keyFor(lang, src);
    final existing = _byKey[key];
    final next = (existing == null)
        ? DictEntry(
            lang: lang, src: src, dst: dst, addedAt: DateTime.now().millisecondsSinceEpoch)
        : existing.copyWith(
            dst: dst, hits: bumpHits ? existing.hits + 1 : existing.hits);
    if (existing != null &&
        existing.dst == next.dst &&
        existing.hits == next.hits) {
      return; // nic się nie zmieniło – nie hałasujemy
    }
    _byKey[key] = next;
    notifyListeners();
    await StorageService.dictionary.put(key, next.toJson());
  }

  Future<void> remove(DictEntry entry) async {
    _byKey.remove(entry.key);
    notifyListeners();
    await StorageService.dictionary.delete(entry.key);
  }

  Future<void> replaceAll(List<DictEntry> entries) async {
    for (final e in entries) {
      _byKey[e.key] = e;
      await StorageService.dictionary.put(e.key, e.toJson());
    }
    notifyListeners();
  }

  /// Słownik w formacie {pytanie: odpowiedź} dla bota (konkretny język).
  Map<String, String> asBotDict(String lang) {
    final out = <String, String>{};
    for (final e in _byKey.values) {
      if (e.lang == lang) out[e.src] = e.dst;
    }
    return out;
  }

  String exportJson({String? lang}) {
    final list = lang == null ? all : byLang(lang);
    const withKey = JsonEncoder.withIndent('  ');
    return withKey.convert(list.map((e) => e.toMap()).toList());
  }

  /// Import: JSON lista [{src,dst,lang}] albo prosty TSV „pytanie\todpowiedź".
  Future<int> importFrom(String content, {String fallbackLang = 'en'}) async {
    final trimmed = content.trim();
    var imported = 0;
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        final list = decoded is List
            ? decoded
            : ((decoded as Map)['entries'] as List? ?? const []);
        for (final item in list) {
          final m = Map<String, dynamic>.from(item as Map);
          final src = (m['src'] ?? m['word'] ?? m['question'] ?? '').toString();
          final dst = (m['dst'] ?? m['translation'] ?? m['answer'] ?? '').toString();
          final lang = (m['lang'] ?? fallbackLang).toString();
          if (src.isEmpty || dst.isEmpty) continue;
          await upsert(lang, src, dst);
          imported++;
        }
        return imported;
      } catch (_) {
        // nie – spróbujemy jako TSV poniżej
      }
    }
    for (final line in trimmed.split(RegExp(r'\r?\n'))) {
      final parts = line.split(RegExp(r'\t|;|,'));
      if (parts.length < 2) continue;
      final src = parts[0].trim();
      final dst = parts[1].trim();
      if (src.isEmpty || dst.isEmpty) continue;
      await upsert(fallbackLang, src, dst);
      imported++;
    }
    return imported;
  }
}
