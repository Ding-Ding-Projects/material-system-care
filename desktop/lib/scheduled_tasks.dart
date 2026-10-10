import 'package:flutter/material.dart';
import 'localization.dart';
import 'motion.dart';

typedef ScheduledTasksInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class ScheduledTasksPage extends StatefulWidget {
  const ScheduledTasksPage({super.key, required this.invoke});
  final ScheduledTasksInvoke invoke;
  @override
  State<ScheduledTasksPage> createState() => _ScheduledTasksPageState();
}

class _ScheduledTasksPageState extends State<ScheduledTasksPage> {
  int limit = 200;
  bool busy = false;
  bool truncated = false;
  String query = '';
  String? error;
  String? observedAt;
  List<Map<String, dynamic>>? records;

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      records = null;
      observedAt = null;
      truncated = false;
    });
    try {
      final result = await widget.invoke('tasks.list', {'limit': limit});
      if (result['records'] is! List ||
          (result['records'] as List).length > limit ||
          result['truncated'] is! bool ||
          result['observedAt'] is! String)
        throw const FormatException();
      final rows = (result['records'] as List).map((value) {
        final row = Map<String, dynamic>.from(value as Map);
        for (final key in ['name', 'path', 'state']) {
          if (row[key] is! String || (row[key] as String).isEmpty)
            throw const FormatException();
        }
        if (row['enabled'] != null && row['enabled'] is! bool ||
            row['infoAvailable'] is! bool ||
            row['lastResult'] != null &&
                (row['lastResult'] is! int ||
                    (row['lastResult'] as int) < 0 ||
                    (row['lastResult'] as int) > 0xffffffff))
          throw const FormatException();
        for (final key in ['lastRun', 'nextRun']) {
          if (row[key] != null && row[key] is! String)
            throw const FormatException();
        }
        return row;
      }).toList();
      if (mounted)
        setState(() {
          records = rows;
          truncated = result['truncated'] as bool;
          observedAt = result['observedAt'] as String;
        });
    } catch (failure) {
      final code = failure is StateError
          ? failure.message.toString().split(':').first
          : '';
      final reason = switch (code) {
        'OPERATION_TIMEOUT' =>
          'Scheduled-task inspection exceeded twenty seconds. Try a smaller limit.',
        'TASK_QUERY_TEARDOWN_INCOMPLETE' =>
          'Inspection stopped waiting, but query-process exit is unverified. No task change was requested.',
        'INVALID_TASK_INVENTORY' =>
          'Task Scheduler returned an invalid or oversized inventory. No partial result is shown.',
        _ =>
          'Scheduled-task inventory is unavailable for this account. No task was run or changed.',
      };
      if (mounted) setState(() => error = reason);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = (records ?? [])
        .where(
          (r) => '${r['name']} ${r['path']} ${r['state']}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const UiText('Scheduled tasks')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              UiText(
                'Review scheduled tasks',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const UiText(
                'Inspect tasks visible to this account. This workspace never runs, enables, disables or changes a task.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int>(
                      initialValue: limit,
                      decoration: InputDecoration(
                        labelText: localize(context, 'Maximum records'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [200, 500, 1000]
                          .map(
                            (n) =>
                                DropdownMenuItem(value: n, child: Text('$n')),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              limit = value!;
                              records = null;
                              error = null;
                              observedAt = null;
                              truncated = false;
                            }),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : refresh,
                    icon: const Icon(Icons.refresh),
                    label: const UiText('Read scheduled tasks'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SearchBar(
                hintText: localize(
                  context,
                  'Filter loaded tasks by name, folder or state',
                ),
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 16),
              OperationMotion(
                state: busy
                    ? 'working'
                    : error != null
                    ? 'error'
                    : records != null
                    ? 'complete'
                    : 'idle',
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Semantics(liveRegion: true, child: UiText(error!)),
              if (records == null && !busy && error == null)
                const UiText(
                  'No task inventory collected. Start an explicit read above.',
                ),
              if (observedAt != null)
                Text('${localize(context, 'Collected at UTC')}: $observedAt'),
              if (truncated)
                const UiText(
                  'The record limit was reached. Filtering searches only the loaded subset; increase the limit for a broader view.',
                ),
              if (records != null)
                const UiText(
                  'Task visibility depends on account access. Reported run times have no timezone; missing times do not prove a task never ran.',
                ),
              if (records != null && visible.isEmpty)
                const UiText('No matching loaded tasks.'),
              ...visible.map(
                (row) => Card.outlined(
                  child: ExpansionTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(row['name'] as String),
                    subtitle: Text('${row['path']} · ${row['state']}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SelectableText('${row['path']}${row['name']}'),
                            UiText(
                              row['enabled'] == true
                                  ? 'Enabled'
                                  : row['enabled'] == false
                                  ? 'Disabled'
                                  : 'Enabled state unavailable',
                            ),
                            if (row['infoAvailable'] != true)
                              const UiText(
                                'Run-time details are unavailable for this task.',
                              ),
                            Text(
                              '${localize(context, 'Reported last run')}: ${row['lastRun'] ?? localize(context, 'Unavailable')}',
                            ),
                            Text(
                              '${localize(context, 'Reported next run')}: ${row['nextRun'] ?? localize(context, 'Unavailable')}',
                            ),
                            Text(
                              '${localize(context, 'Last result code')}: ${row['lastResult'] == null ? localize(context, 'Unavailable') : '0x${(row['lastResult'] as int).toRadixString(16).toUpperCase().padLeft(8, '0')}'}',
                            ),
                            const UiText(
                              'Result codes can describe scheduler status. A nonzero value alone is not a diagnosis.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              const UiText(
                'Action commands, arguments, principals and credentials are excluded. Results are not uploaded or automatically saved.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
