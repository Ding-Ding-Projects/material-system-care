import 'package:flutter/material.dart';
import 'inspection_app_bar.dart';
import 'labeled_controls.dart';
import 'localization.dart';
import 'motion.dart';

typedef StartupInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class StartupRecord {
  const StartupRecord(
    this.id,
    this.enabled,
    this.revision,
    this.canChange,
    this.conflict,
    this.command,
  );
  final String id, revision;
  final bool enabled, canChange, conflict;
  final String? command;

  static List<StartupRecord> parse(Map<String, dynamic> result) {
    final raw = result['records'];
    if (raw is! List || raw.length > 20000) throw const FormatException();
    final keys = <String>{};
    return raw.map((item) {
      if (item is! Map) throw const FormatException();
      final id = item['id'], enabled = item['enabled'];
      final revision = item['reviewRevision'], command = item['command'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 256 ||
          id.runes.any((c) => c < 32 || c == 127) ||
          enabled is! bool ||
          item['scope'] != 'user' ||
          item['canChange'] is! bool ||
          item['recoveryRequired'] is! bool ||
          revision is! String ||
          !RegExp(r'^[0-9A-F]{64}$').hasMatch(revision) ||
          item['source'] != (enabled ? 'HKCU.Run' : 'originalStateJournal') ||
          (command != null && (command is! String || command.length > 32768)) ||
          !keys.add('$id/$enabled'))
        throw const FormatException();
      final conflict = item['recoveryRequired'] as bool;
      return StartupRecord(
        id,
        enabled,
        revision,
        item['canChange'] == true && !conflict,
        conflict,
        command as String?,
      );
    }).toList();
  }
}

class StartupPage extends StatefulWidget {
  const StartupPage({super.key, required this.invoke});
  final StartupInvoke invoke;
  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  List<StartupRecord>? records;
  bool busy = false, reviewing = false;
  String query = '';
  String filter = 'All entries';
  String? message;
  bool failed = false;

  Future<bool> readRecords() async {
    try {
      final next = StartupRecord.parse(await widget.invoke('startup.list', {}));
      if (mounted) setState(() => records = next);
      return true;
    } catch (_) {
      if (mounted) setState(() => records = null);
      return false;
    }
  }

  Future<void> refresh() async {
    if (busy || reviewing) return;
    setState(() {
      busy = true;
      message = null;
      records = null;
    });
    final loaded = await readRecords();
    if (mounted)
      setState(() {
        busy = false;
        failed = !loaded;
        message = loaded
            ? 'Startup records refreshed.'
            : 'Startup records are unavailable or invalid. No change was requested.';
      });
  }

  Future<void> change(StartupRecord record) async {
    if (busy || reviewing || !record.canChange) return;
    setState(() => reviewing = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => CopyScope(
        preferences: CopyScope.of(context),
        child: AlertDialog(
          title: UiText(
            record.enabled
                ? 'Disable selected startup entry'
                : 'Enable selected startup entry',
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(record.id),
                const SizedBox(height: 16),
                UiText(
                  record.enabled
                      ? 'Remove this user startup entry after saving its original command for restoration.'
                      : 'Restore the saved original startup command for this user. An existing entry with the same name will not be overwritten.',
                ),
                const SizedBox(height: 12),
                const UiText(
                  'This changes future sign-in behavior. It does not start or stop a running process.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const UiText('Confirm selected action'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => reviewing = false);
    if (accepted != true) return;
    setState(() {
      busy = true;
      message = null;
    });
    bool completed = false, stale = false;
    try {
      final result = await widget.invoke('startup.set', {
        'id': record.id,
        'enabled': !record.enabled,
        'reviewRevision': record.revision,
        'confirmed': true,
      });
      if (result['completed'] != true ||
          result['id'] != record.id ||
          result['enabled'] != !record.enabled ||
          result['restartInitiated'] != false)
        throw const FormatException();
      completed = true;
    } catch (error) {
      stale = error.toString().contains('STARTUP_REVIEW_CHANGED');
    }
    final loaded = await readRecords();
    if (!mounted) return;
    setState(() {
      busy = false;
      failed = !completed || !loaded;
      message = stale
          ? 'The startup record changed. Records were refreshed where available. Review the selected action again.'
          : completed && loaded
          ? 'Startup change completed and records refreshed.'
          : completed
          ? 'The change completed, but refreshed records are unavailable.'
          : 'The startup change was not confirmed. Review refreshed records before trying again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final needle = query.toLowerCase();
    final visible = (records ?? <StartupRecord>[])
        .where(
          (record) =>
              (filter == 'All entries' ||
                  (filter == 'Enabled' ? record.enabled : !record.enabled)) &&
              ('${record.id} ${record.command ?? ''}').toLowerCase().contains(
                needle,
              ),
        )
        .toList();
    return Scaffold(
      appBar: inspectionAppBar(context, 'Startup'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              UiText(
                'Review sign-in entries',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const UiText(
                'Review current-user startup commands and saved restoration records. Machine and startup-folder entries are outside this workflow.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: busy || reviewing ? null : refresh,
                    icon: const Icon(Icons.refresh),
                    label: const UiText('Refresh records'),
                  ),
                  SizedBox(
                    width: 230,
                    child: LabeledControl(
                      label: localize(context, 'Startup state'),
                      child: DropdownButtonFormField<String>(
                        initialValue: filter,
                        isExpanded: true,
                        isDense: false,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: ['All entries', 'Enabled', 'Disabled']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: UiText(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => filter = value!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LabeledSearchBar(
                label: localize(context, 'Filter startup records'),
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 16),
              OperationMotion(
                state: busy
                    ? 'working'
                    : failed
                    ? 'error'
                    : records != null
                    ? 'complete'
                    : 'idle',
              ),
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Semantics(
                  liveRegion: true,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: UiText(message!),
                    ),
                  ),
                ),
              if (!busy && records == null && message == null)
                const UiText(
                  'Read startup records to begin. Nothing changes until you review and confirm an entry.',
                ),
              if (records != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '${localize(context, 'Matching entries')}: ${visible.length} / ${records!.length}',
                  ),
                ),
              if (records != null && visible.isEmpty)
                const UiText('No startup entries match the current filter.'),
              for (final record in visible)
                Card(
                  key: ValueKey('${record.id}/${record.enabled}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          record.id,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        UiText(
                          record.enabled
                              ? 'Enabled at sign-in'
                              : 'Disabled with saved restoration record',
                        ),
                        if (record.conflict)
                          const UiText(
                            'A conflicting recovery record needs attention. This entry cannot be changed here.',
                          ),
                        if (!record.canChange && !record.conflict)
                          const UiText('This entry is read-only.'),
                        if (record.command != null)
                          ExpansionTile(
                            expansionAnimationStyle:
                                MediaQuery.disableAnimationsOf(context)
                                ? const AnimationStyle(
                                    duration: Duration.zero,
                                    reverseDuration: Duration.zero,
                                  )
                                : null,
                            title: const UiText('Startup command'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SelectableText(record.command!),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: busy || reviewing || !record.canChange
                                ? null
                                : () => change(record),
                            icon: Icon(
                              record.enabled
                                  ? Icons.pause_circle_outline
                                  : Icons.restore,
                            ),
                            label: UiText(
                              record.enabled
                                  ? 'Review disable'
                                  : 'Review enable',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
