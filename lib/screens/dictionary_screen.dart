import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:linguapilot/l10n_ext.dart';
import 'package:linguapilot/models/dict_entry.dart';
import 'package:linguapilot/providers/dictionary_provider.dart';
import 'package:linguapilot/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  String _query = '';
  String _langFilter = ''; // '' = wszystkie

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    final dict = context.watch<DictionaryProvider>();
    final lessonLang = context.watch<SettingsProvider>().s.lessonLang;

    final entries =
        dict.search(_query, lang: _langFilter.isEmpty ? null : _langFilter);

    return SafeArea(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t.dictTitle,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    Text(
                      dict.all.isEmpty
                          ? t.dictCount(0)
                          : t.dictCount(dict.all.length),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: t.dictSearchHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(t.dictFilterAll),
                      selected: _langFilter.isEmpty,
                      onSelected: (_) => setState(() => _langFilter = ''),
                    ),
                    ChoiceChip(
                      label: Text(lessonLang.toUpperCase()),
                      selected: _langFilter == lessonLang,
                      onSelected: (_) =>
                          setState(() => _langFilter = lessonLang),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyDict(
                        body: _query.isEmpty && _langFilter.isEmpty
                            ? t.dictEmptyBody
                            : t.search,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: entries.length,
                        itemBuilder: (context, i) => _DictTile(
                          entry: entries[i],
                          onEdit: () => showDictEditor(context,
                              existing: entries[i]),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'import',
                  tooltip: t.dictImport,
                  onPressed: () => _import(context),
                  child: const Icon(Icons.file_upload_outlined),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'export',
                  tooltip: t.dictExport,
                  onPressed: () => _export(context),
                  child: const Icon(Icons.file_download_outlined),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'add',
                  tooltip: t.add,
                  onPressed: () => showDictEditor(context),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final t = tr(context);
    final json = context.read<DictionaryProvider>().exportJson();
    await Share.share(json);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.dictExportDone)));
    }
  }

  Future<void> _import(BuildContext context) async {
    final t = tr(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    String? content;
    try {
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }
    } catch (_) {
      content = null;
    }
    if (content == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.dictImportError)));
      }
      return;
    }
    if (!context.mounted) return;
    final lang = context.read<SettingsProvider>().s.lessonLang;
    final count = await context
        .read<DictionaryProvider>()
        .importFrom(content, fallbackLang: lang);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.dictImportDone(count))));
    }
  }
}

/// Dialog dodawania / edycji słówka (używany też z poziomu kafelka).
Future<void> showDictEditor(BuildContext context, {DictEntry? existing}) async {
  final t = tr(context);
  final srcController = TextEditingController(text: existing?.src ?? '');
  final dstController = TextEditingController(text: existing?.dst ?? '');

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? t.dictAddTitle : t.dictEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: srcController,
            decoration: InputDecoration(labelText: t.dictWordLabel),
            autofocus: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: dstController,
            decoration: InputDecoration(labelText: t.dictTranslationLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t.save),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    final lang = context.read<SettingsProvider>().s.lessonLang;
    await context.read<DictionaryProvider>().upsert(
        existing?.lang ?? lang, srcController.text, dstController.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.dictAdded)));
    }
  }
  srcController.dispose();
  dstController.dispose();
}

class _DictTile extends StatelessWidget {
  final DictEntry entry;
  final VoidCallback onEdit;
  const _DictTile({required this.entry, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(entry.src),
        subtitle: Text(entry.dst),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              onEdit();
            } else if (v == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(t.dictDeleteConfirm),
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
                await context.read<DictionaryProvider>().remove(entry);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.dictDeleted)));
                }
              }
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(t.edit)),
            PopupMenuItem(value: 'delete', child: Text(t.delete)),
          ],
        ),
      ),
    );
  }
}

class _EmptyDict extends StatelessWidget {
  final String body;
  const _EmptyDict({required this.body});

  @override
  Widget build(BuildContext context) {
    final t = tr(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(t.dictEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
