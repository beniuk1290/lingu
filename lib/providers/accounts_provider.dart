import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../services/storage_service.dart';

/// Do dwa konta InstaLing – każde z własną sesją (ciasteczkami) i statystykami.
class AccountsProvider extends ChangeNotifier {
  final List<Account> _accounts = [];

  List<Account> get accounts => List.unmodifiable(_accounts);
  int get count => _accounts.length;
  bool get canAdd => _accounts.length < 2;

  Account? get active {
    final id = StorageService.activeAccountId;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  void load() {
    _accounts.clear();
    for (final key in StorageService.accounts.keys) {
      final raw = StorageService.accounts.get(key);
      if (raw == null) continue;
      try {
        _accounts.add(Account.fromJson(raw));
      } catch (_) {
        // pomijamy uszkodzony rekord
      }
    }
    if (active == null && _accounts.isNotEmpty) {
      StorageService.setActiveAccountId(_accounts.first.id);
    }
    notifyListeners();
  }

  Future<Account> add(String name) async {
    final account = Account(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _accounts.add(account);
    await _persist(account);
    if (_accounts.length == 1) {
      await StorageService.setActiveAccountId(account.id);
    }
    notifyListeners();
    return account;
  }

  Future<void> rename(Account account, String name) async {
    account.name = name.trim();
    await _persist(account);
    notifyListeners();
  }

  Future<void> setActive(Account account) async {
    await StorageService.setActiveAccountId(account.id);
    notifyListeners();
  }

  Future<void> remove(Account account) async {
    _accounts.removeWhere((a) => a.id == account.id);
    await StorageService.accounts.delete(account.id);
    final activeId = StorageService.activeAccountId;
    if (activeId == account.id && _accounts.isNotEmpty) {
      await StorageService.setActiveAccountId(_accounts.first.id);
    }
    notifyListeners();
  }

  Future<void> saveCookies(Account account, Map<String, String> cookies) async {
    account.cookies = cookies;
    await _persist(account);
  }

  /// Zapisuje adres panelu ucznia wykryty po zalogowaniu (bez notify –
  /// nie wpływa na UI, a nadmiarowe przebudowy ekranów są niepotrzebne).
  Future<void> savePanelUrl(Account account, String url) async {
    if (account.panelUrl == url) return;
    account.panelUrl = url;
    await _persist(account);
  }

  Future<void> recordSession(int newWords) async {
    final a = active;
    if (a == null) return;
    a.recordSession(newWords, DateTime.now());
    await _persist(a);
    notifyListeners();
  }

  Future<void> _persist(Account a) =>
      StorageService.accounts.put(a.id, a.toJson());
}
