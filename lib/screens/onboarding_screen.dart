import 'package:flutter/material.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/providers/accounts_provider.dart';
import 'package:linguapilot/providers/settings_provider.dart';
import 'package:linguapilot/screens/home_screen.dart';
import 'package:linguapilot/screens/login_webview_screen.dart';
import 'package:linguapilot/services/notification_service.dart';
import 'package:linguapilot/services/storage_service.dart';
import 'package:provider/provider.dart';

/// Kreator pierwszego uruchomienia – konfiguruje język, konto i przypomnienia.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;

  // dane zbierane w kreatorze
  String _lessonLang = 'en';
  String _accountName = '';
  bool _remindersOn = false;
  String _reminder1 = '18:00';
  String? _reminder2;

  static const _totalSteps = 7;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      _goTo(_step + 1);
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    final settings = context.read<SettingsProvider>();
    final accounts = context.read<AccountsProvider>();

    // 1. konto
    if (accounts.accounts.isEmpty) {
      final name = _accountName.trim().isEmpty ? 'Moje konto' : _accountName.trim();
      await accounts.add(name);
    }

    // 2. język lekcji + przypomnienia
    await settings.update(settings.s.copyWith(
      lessonLang: _lessonLang,
      remindersEnabled: _remindersOn,
      reminder1: _reminder1,
      reminder2: _reminder2,
    ));

    // 3. zgoda na powiadomienia (jeśli włączono)
    if (_remindersOn) {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.apply(
        enabled: true,
        reminder1: _reminder1,
        reminder2: _reminder2,
      );
    }

    await StorageService.setOnboarded();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    t.obStep(_step + 1, _totalSteps),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_step < _totalSteps - 1)
                    TextButton(onPressed: _skip, child: Text(t.obSkip)),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (_step + 1) / _totalSteps,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomePage(title: t.obWelcomeTitle, body: t.obWelcomeBody),
                  _LangPickerPage(
                    title: t.obLangTitle,
                    body: t.obLangBody,
                  ),
                  _AccountNamePage(
                    title: t.obAccountTitle,
                    body: t.obAccountBody,
                    label: t.obAccountName,
                    onName: (v) => _accountName = v,
                    initial: _accountName,
                  ),
                  _LoginPage(
                    title: t.obLoginTitle,
                    body: t.obLoginBody,
                    openLabel: t.obLoginOpen,
                    doneLabel: t.obLoginDone,
                  ),
                  _LessonLangPage(
                    title: t.obLessonTitle,
                    body: t.obLessonBody,
                    selected: _lessonLang,
                    onSelect: (v) => setState(() => _lessonLang = v),
                  ),
                  _ReminderPage(
                    title: t.obReminderTitle,
                    body: t.obReminderBody,
                    enabled: _remindersOn,
                    onToggle: (v) => setState(() => _remindersOn = v),
                    reminder1: _reminder1,
                    reminder2: _reminder2,
                    onPick1: (v) => setState(() => _reminder1 = v),
                    onPick2: (v) => setState(() => _reminder2 = v),
                  ),
                  _WelcomePage(title: t.obFinishTitle, body: t.obFinishBody),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(
                      _step == _totalSteps - 1 ? Icons.check : Icons.arrow_forward),
                  label: Text(_step == _totalSteps - 1 ? t.finish : t.next),
                  onPressed: _next,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- strony

class _WelcomePage extends StatelessWidget {
  final String title;
  final String body;
  const _WelcomePage({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.smart_toy_outlined,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(body, style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}

class _LangPickerPage extends StatelessWidget {
  final String title;
  final String body;
  const _LangPickerPage({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final settings = context.watch<SettingsProvider>();
    final current = settings.s.appLocale;

    Widget tile(String? code, String label) => ListTile(
          title: Text(label),
          trailing: current == code
              ? Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary)
              : const Icon(Icons.circle_outlined),
          onTap: () => settings.update(settings.s.copyWith(
              appLocale: code ?? 'pl', clearAppLocale: code == null)),
        );

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 20),
          tile(null, t.settAppLangSystem),
          tile('pl', 'Polski 🇵🇱'),
          tile('en', 'English 🇬🇧'),
          tile('de', 'Deutsch 🇩🇪'),
        ],
      ),
    );
  }
}

class _AccountNamePage extends StatelessWidget {
  final String title;
  final String body;
  final String label;
  final String initial;
  final ValueChanged<String> onName;
  const _AccountNamePage({
    required this.title,
    required this.body,
    required this.label,
    required this.initial,
    required this.onName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(labelText: label),
            autofocus: true,
            onChanged: onName,
          ),
        ],
      ),
    );
  }
}

class _LoginPage extends StatelessWidget {
  final String title;
  final String body;
  final String openLabel;
  final String doneLabel;
  const _LoginPage({
    required this.title,
    required this.body,
    required this.openLabel,
    required this.doneLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline)),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text(openLabel),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const LoginWebViewScreen()),
            ),
          ),
          const SizedBox(height: 12),
          Text(doneLabel,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline)),
          const Spacer(),
        ],
      ),
    );
  }
}

class _LessonLangPage extends StatelessWidget {
  final String title;
  final String body;
  final String selected;
  final ValueChanged<String> onSelect;
  const _LessonLangPage({
    required this.title,
    required this.body,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const langs = {
      'en': 'Angielski 🇬🇧',
      'de': 'Niemiecki 🇩🇪',
      'es': 'Hiszpański 🇪🇸',
      'fr': 'Francuski 🇫🇷',
      'it': 'Włoski 🇮🇹',
      'uk': 'Ukraiński 🇺🇦',
      'ru': 'Rosyjski 🇷🇺',
    };
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: langs.entries
                  .map((e) => ListTile(
                        title: Text(e.value),
                        trailing: selected == e.key
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : const Icon(Icons.circle_outlined),
                        onTap: () => onSelect(e.key),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderPage extends StatelessWidget {
  final String title;
  final String body;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final String reminder1;
  final String? reminder2;
  final ValueChanged<String> onPick1;
  final ValueChanged<String> onPick2;

  const _ReminderPage({
    required this.title,
    required this.body,
    required this.enabled,
    required this.onToggle,
    required this.reminder1,
    required this.reminder2,
    required this.onPick1,
    required this.onPick2,
  });

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(t.settReminders),
            subtitle: Text(t.settRemindersDesc),
            value: enabled,
            onChanged: (v) async {
              if (v) {
                await NotificationService.instance.requestPermissions();
              }
              onToggle(v);
            },
          ),
          if (enabled) ...[
            ListTile(
              title: Text(t.settReminder1),
              trailing: Text(reminder1,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              onTap: () async {
                final picked = await _pickTime(context, reminder1);
                if (picked != null) onPick1(picked);
              },
            ),
            ListTile(
              title: Text(t.settReminder2),
              trailing: Text(reminder2 ?? '–',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              onTap: () async {
                final picked = await _pickTime(context, reminder2 ?? '20:00');
                if (picked != null) onPick2(picked);
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _pickTime(BuildContext context, String current) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 18,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
    final v = await showTimePicker(context: context, initialTime: initial);
    if (v == null) return null;
    return '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }
}
