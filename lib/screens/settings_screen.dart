import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/models/app_settings.dart';
import 'package:linguapilot/providers/settings_provider.dart';
import 'package:linguapilot/services/notification_service.dart';
import 'package:linguapilot/theme/app_theme.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(t.settTitle,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            TabBar(
              tabs: [
                Tab(text: t.settTabBasic),
                Tab(text: t.settTabAdvanced),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _BasicTab(),
                  _AdvancedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- podstawowe

class _BasicTab extends StatelessWidget {
  const _BasicTab();

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final settings = context.watch<SettingsProvider>();
    final s = settings.s;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(t.settSectionLook),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(t.settTheme),
                subtitle: Text(switch (s.themeMode) {
                  'light' => t.settThemeLight,
                  'dark' => t.settThemeDark,
                  _ => t.settThemeSystem,
                }),
                onTap: () => _pickTheme(context, s),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text(t.settAccent),
                subtitle: Wrap(
                  spacing: 8,
                  children: kAccentOptions
                      .map((a) => GestureDetector(
                            onTap: () => settings
                                .update(s.copyWith(accentId: a.id)),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: a.color,
                                shape: BoxShape.circle,
                                border: s.accentId == a.id
                                    ? Border.all(
                                        color:
                                            Theme.of(context).colorScheme.outline,
                                        width: 3)
                                    : null,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.translate_outlined),
                title: Text(t.settAppLang),
                subtitle: Text(s.appLocale == null
                    ? t.settAppLangSystem
                    : _langLabel(s.appLocale!)),
                onTap: () => _pickAppLang(context, s),
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(t.settLessonLang),
                subtitle: Text(_langLabel(s.lessonLang)),
                onTap: () => _pickLessonLang(context, settings),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionHeader(t.settSectionBot),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.speed_outlined),
                title: Text(t.settSpeed),
                subtitle: Text(switch (s.speedPreset) {
                  'slow' => t.speedSlow,
                  'fast' => t.speedFast,
                  'custom' => t.speedCustom,
                  _ => t.speedNormal,
                }),
                onTap: () => _pickSpeed(context, settings),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.play_circle_outline),
                title: Text(t.settAutoStart),
                subtitle: Text(t.settAutoStartDesc),
                value: s.autoStart,
                onChanged: (v) => settings.update(s.copyWith(autoStart: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(t.settReminders),
                subtitle: Text(t.settRemindersDesc),
                value: s.remindersEnabled,
                onChanged: (v) => _toggleReminders(context, settings, v),
              ),
              if (s.remindersEnabled)
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(t.settReminder1),
                  trailing: Text(s.reminder1,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  onTap: () => _pickTime(context, s.reminder1, (v) =>
                      settings.update(s.copyWith(reminder1: v))),
                ),
              if (s.remindersEnabled)
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text(t.settReminder2),
                  trailing: Text(s.reminder2 ?? '–',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  onTap: () => _pickTime(context, s.reminder2 ?? '20:00', (v) =>
                      settings.update(s.copyWith(reminder2: v))),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleReminders(BuildContext context,
      SettingsProvider settings, bool enable) async {
    if (enable) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr(context).permBody)));
        }
        return;
      }
    }
    await settings.update(
        settings.s.copyWith(remindersEnabled: enable));
  }

  Future<void> _pickTheme(BuildContext context, AppSettings s) async {
    final t = tr(context);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.settTheme),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'system'),
              child: Text(t.settThemeSystem)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'light'),
              child: Text(t.settThemeLight)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'dark'),
              child: Text(t.settThemeDark)),
        ],
      ),
    );
    if (v != null && context.mounted) {
      context.read<SettingsProvider>().update(s.copyWith(themeMode: v));
    }
  }

  Future<void> _pickAppLang(BuildContext context, AppSettings s) async {
    final t = tr(context);
    const system = '__system__';
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.settAppLang),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, system),
              child: Text(t.settAppLangSystem)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'pl'),
              child: const Text('Polski')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'en'),
              child: const Text('English')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'de'),
              child: const Text('Deutsch')),
        ],
      ),
    );
    if (v != null && context.mounted) {
      context.read<SettingsProvider>().update(
          s.copyWith(appLocale: v, clearAppLocale: v == system));
    }
  }

  Future<void> _pickLessonLang(
      BuildContext context, SettingsProvider settings) async {
    final t = tr(context);
    const langs = ['en', 'de', 'es', 'fr', 'it', 'uk', 'ru'];
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.settLessonLang),
        children: langs
            .map((l) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, l),
                  child: Text(_langLabel(l)),
                ))
            .toList(),
      ),
    );
    if (v != null && context.mounted) {
      settings.update(settings.s.copyWith(lessonLang: v));
    }
  }

  Future<void> _pickSpeed(
      BuildContext context, SettingsProvider settings) async {
    final t = tr(context);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.settSpeed),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'slow'),
              child: Text(t.speedSlow)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'normal'),
              child: Text(t.speedNormal)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'fast'),
              child: Text(t.speedFast)),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'custom'),
              child: Text(t.speedCustom)),
        ],
      ),
    );
    if (v != null && context.mounted) {
      settings.update(settings.s.copyWith(speedPreset: v));
    }
  }

  Future<void> _pickTime(BuildContext context, String current,
      ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 18,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
    final v = await showTimePicker(context: context, initialTime: initial);
    if (v != null) {
      onPicked(
          '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}');
    }
  }

  static String _langLabel(String code) => switch (code) {
        'pl' => 'Polski',
        'en' => 'English',
        'de' => 'Deutsch',
        'es' => 'Español',
        'fr' => 'Français',
        'it' => 'Italiano',
        'uk' => 'Українська',
        'ru' => 'Русский',
        _ => code.toUpperCase(),
      };
}

// --------------------------------------------------------------- zaawansowane

class _AdvancedTab extends StatelessWidget {
  const _AdvancedTab();

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final settings = context.watch<SettingsProvider>();
    final s = settings.s;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t.advIntro,
            style: TextStyle(
                fontSize: 13, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(height: 12),
        _SectionHeader(t.advTypingSection),
        Card(
          child: Column(
            children: [
              _SliderTile(
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: t.advTypingMin,
                value: s.typingMin.toDouble(),
                min: 20,
                max: 250,
                unit: t.advUnitMs,
                enabled: s.speedPreset == 'custom',
                onChanged: (v) => settings
                    .update(s.copyWith(typingMin: v.round())),
              ),
              _SliderTile(
                icon: const Icon(Icons.keyboard),
                label: t.advTypingMax,
                value: s.typingMax.toDouble(),
                min: 40,
                max: 400,
                unit: t.advUnitMs,
                enabled: s.speedPreset == 'custom',
                onChanged: (v) => settings
                    .update(s.copyWith(typingMax: v.round())),
              ),
              _SliderTile(
                icon: const Icon(Icons.backspace_outlined),
                label: t.advTypoRate,
                description: t.advTypoRateDesc,
                value: s.typoRatePct.toDouble(),
                min: 0,
                max: 15,
                divisions: 15,
                unit: '%',
                onChanged: (v) => settings
                    .update(s.copyWith(typoRatePct: v.round())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionHeader(t.advDelaysSection),
        Card(
          child: Column(
            children: [
              _SliderTile(
                icon: const Icon(Icons.hourglass_bottom_outlined),
                label: t.advWordDelay,
                value: s.wordDelay.toDouble(),
                min: 300,
                max: 3000,
                unit: t.advUnitMs,
                onChanged: (v) =>
                    settings.update(s.copyWith(wordDelay: v.round())),
              ),
              _SliderTile(
                icon: const Icon(Icons.timer_outlined),
                label: t.advTickDelay,
                value: s.tickDelay.toDouble(),
                min: 300,
                max: 3000,
                unit: t.advUnitMs,
                onChanged: (v) =>
                    settings.update(s.copyWith(tickDelay: v.round())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionHeader(t.advMistakesSection),
        Card(
          child: Column(
            children: [
              _SliderTile(
                icon: const Icon(Icons.error_outline),
                label: t.advErrorRate,
                description: t.advErrorRateDesc,
                value: s.errorRatePct.toDouble(),
                min: 0,
                max: 30,
                divisions: 30,
                unit: '%',
                onChanged: (v) => settings
                    .update(s.copyWith(errorRatePct: v.round())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionHeader(t.advBehaviorSection),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_stories_outlined),
                title: Text(t.advAutoLearn),
                subtitle: Text(t.advAutoLearnDesc),
                value: s.autoLearn,
                onChanged: (v) => settings.update(s.copyWith(autoLearn: v)),
              ),
              ListTile(
                leading: const Icon(Icons.tag_outlined),
                title: Text(t.advMaxWords),
                trailing: Text(
                  s.maxWords == 0
                      ? t.advMaxWordsUnlimited
                      : s.maxWords.toString(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onTap: () => _pickMaxWords(context, settings),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_outlined),
                title: Text(t.advDebugLog),
                subtitle: Text(t.advDebugLogDesc),
                value: s.debugLog,
                onChanged: (v) => settings.update(s.copyWith(debugLog: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionHeader(t.advPrivacySection),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.theaters_outlined),
                title: Text(t.advIncognito),
                subtitle: Text(t.advIncognitoDesc),
                value: s.incognito,
                onChanged: (v) => settings.update(s.copyWith(incognito: v)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: t.advUserAgent,
                    hintText: t.advUserAgentHint,
                  ),
                  controller: TextEditingController(text: s.userAgent)
                    ..selection = TextSelection.collapsed(
                        offset: s.userAgent.length),
                  onChanged: (v) =>
                      settings.update(s.copyWith(userAgent: v)),
                ),
              ),
              ListTile(
                leading: Icon(Icons.cleaning_services_outlined,
                    color: Theme.of(context).colorScheme.error),
                title: Text(t.advClearData),
                onTap: () => _confirmClearData(context, settings),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(t.advReset),
            onTap: () => _confirmReset(context, settings),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _pickMaxWords(
      BuildContext context, SettingsProvider settings) async {
    final t = tr(context);
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.advMaxWords),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 0),
              child: Text(t.advMaxWordsUnlimited)),
          for (final n in const [10, 20, 30, 50])
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, n),
                child: Text(n.toString())),
        ],
      ),
    );
    if (v != null && context.mounted) {
      settings.update(settings.s.copyWith(maxWords: v));
    }
  }

  Future<void> _confirmClearData(
      BuildContext context, SettingsProvider settings) async {
    final t = tr(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.advClearData),
        content: Text(t.advClearDataConfirm),
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
    if (ok == true) {
      try {
        await CookieManager.instance().deleteAllCookies();
      } catch (_) {
        // WebView jeszcze nie wystartował – nic do czyszczenia
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.advClearDataDone)));
      }
    }
  }

  Future<void> _confirmReset(
      BuildContext context, SettingsProvider settings) async {
    final t = tr(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.advReset),
        content: Text(t.advResetConfirm),
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
    if (ok == true && context.mounted) {
      await settings.reset();
    }
  }
}

// ----------------------------------------------------------------- pomocnicze

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final Icon icon;
  final String label;
  final String? description;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.label,
    this.description,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.unit,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(child: Text(label)),
                Text('${value.round()} $unit',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
            if (description != null)
              Text(description!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline)),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
