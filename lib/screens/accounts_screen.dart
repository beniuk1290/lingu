import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/models/account.dart';
import 'package:linguapilot/providers/accounts_provider.dart';
import 'package:linguapilot/screens/login_webview_screen.dart';
import 'package:provider/provider.dart';

const kInstaLingOrigin = 'https://instaling.pl';

/// Zapisuje ciasteczka instaling.pl w aktywnym koncie i czyści je,
/// aby kolejna osoba / konto mogła zalogować się w czystej sesji.
Future<void> snapshotAndClearCookies(AccountsProvider provider) async {
  try {
    final cm = CookieManager.instance();
    final cookies = await cm.getCookies(url: WebUri(kInstaLingOrigin));
    final map = <String, String>{};
    for (final c in cookies) {
      map[c.name] = c.value;
    }
    await provider.saveCookies(provider.active!, map);
    await cm.deleteAllCookies();
  } catch (_) {
    // WebView nie wystartował – nie ma czego zapisywać
  }
}

/// Wczytuje zapisane ciasteczka aktywnego konta do WebView.
Future<void> restoreCookiesFor(Account account) async {
  if (account.cookies.isEmpty) return;
  try {
    final cm = CookieManager.instance();
    for (final entry in account.cookies.entries) {
      await cm.setCookie(
        url: WebUri(kInstaLingOrigin),
        name: entry.key,
        value: entry.value,
        domain: '.instaling.pl',
        path: '/',
      );
    }
  } catch (_) {
    // ignorujemy – użytkownik zaloguje się ręcznie
  }
}

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final provider = context.watch<AccountsProvider>();
    final active = provider.active;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(t.accTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(t.accIntro,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 16),
          for (final account in provider.accounts)
            _AccountCard(
              account: account,
              isActive: account.id == active?.id,
            ),
          const SizedBox(height: 12),
          if (provider.canAdd)
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(t.accAdd),
              onPressed: () => _addAccount(context),
            )
          else
            Text(t.accMaxTwo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  Future<void> _addAccount(BuildContext context) async {
    final t = tr(context);
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.accAdd),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: t.accNameLabel),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, nameController.text),
              child: Text(t.next)),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    final provider = context.read<AccountsProvider>();
    // bieżące ciasteczka trafiają do poprzedniego konta, a sesja jest czyszczona
    if (provider.active != null) {
      await snapshotAndClearCookies(provider);
    }
    await provider.add(name);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginWebViewScreen()),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final bool isActive;
  const _AccountCard({required this.account, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final scheme = Theme.of(context).colorScheme;
    final provider = context.read<AccountsProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isActive ? Icons.person : Icons.person_outline,
                    color: isActive ? scheme.primary : scheme.outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(account.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t.accCurrent,
                        style: TextStyle(
                            color: scheme.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.accStats(account.sessions, account.wordsLearned),
              style: TextStyle(fontSize: 13, color: scheme.outline),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isActive)
                  FilledButton.tonal(
                    onPressed: () => _switch(context, provider),
                    child: Text(t.accSwitch),
                  ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LoginWebViewScreen()),
                  ),
                  child: Text(t.accLogin),
                ),
                IconButton(
                  tooltip: t.delete,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: () => _delete(context, provider, t),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switch(BuildContext context, AccountsProvider provider) async {
    final t = tr(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.accSwitchConfirm(account.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.ok)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final old = provider.active;
    if (old != null) {
      await snapshotAndClearCookies(provider);
    }
    await provider.setActive(account);
    await restoreCookiesFor(account);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.accSwitched(account.name))),
      );
    }
  }

  Future<void> _delete(
      BuildContext context, AccountsProvider provider, dynamic t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.accDeleteConfirm(account.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.delete)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await provider.remove(account);
    }
  }
}
