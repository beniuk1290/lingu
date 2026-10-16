import 'package:flutter/material.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/providers/accounts_provider.dart';
import 'package:linguapilot/providers/dictionary_provider.dart';
import 'package:linguapilot/screens/accounts_screen.dart';
import 'package:linguapilot/screens/dictionary_screen.dart';
import 'package:linguapilot/screens/lesson_screen.dart';
import 'package:linguapilot/screens/settings_screen.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _HomeTab(),
          DictionaryScreen(),
          SettingsScreen(),
          AccountsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t.navHome),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: t.navDictionary),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: t.navSettings),
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: t.navAccounts),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final theme = Theme.of(context);
    final account = context.watch<AccountsProvider>().active;
    final dictCount = context.watch<DictionaryProvider>().length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(t.appTitle, style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800)),
          Text(t.appSubtitle, style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        account?.doneToday == true
                            ? Icons.celebration_outlined
                            : Icons.bolt,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          account?.doneToday == true
                              ? t.homeDoneToday
                              : t.homeReady,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(t.homeStart),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LessonScreen()),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(t.homeStartHint,
                      style: TextStyle(
                          fontSize: 12, color: theme.colorScheme.outline)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow(
                    icon: Icons.local_fire_department_outlined,
                    label: t.homeStreak(account?.streak ?? 0),
                  ),
                  const Divider(height: 16),
                  _StatRow(
                    icon: Icons.book_outlined,
                    label: t.homeWords(dictCount),
                  ),
                  const Divider(height: 16),
                  _StatRow(
                    icon: Icons.check_circle_outline,
                    label: t.homeSessions(account?.sessions ?? 0),
                  ),
                  if (account != null) ...[
                    const Divider(height: 16),
                    _StatRow(
                      icon: Icons.person_outline,
                      label: t.homeActiveAccount(account.name),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}
