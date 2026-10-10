import 'package:flutter/material.dart';
import 'localization.dart';
import 'inspection_app_bar.dart';
import 'motion.dart';

typedef ProcessInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class ProcessesPage extends StatefulWidget {
  const ProcessesPage({super.key, required this.invoke});
  final ProcessInvoke invoke;
  @override
  State<ProcessesPage> createState() => _ProcessesPageState();
}

class _ProcessesPageState extends State<ProcessesPage> {
  List<Map<String, dynamic>>? records;
  bool busy = false;
  bool reviewing = false;
  String query = '';
  String? error;
  String? receipt;

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      records = null;
      error = null;
      receipt = null;
    });
    try {
      final result = await widget.invoke('processes.list', {});
      if (result['records'] is! List) throw const FormatException();
      final rows = (result['records'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (mounted) setState(() => records = rows);
    } catch (_) {
      if (mounted)
        setState(
          () =>
              error = 'Process records are unavailable. Refresh to try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool eligible(Map<String, dynamic> row) =>
      row['canRequestClose'] == true &&
      row['pid'] is int &&
      (row['pid'] as int) > 0 &&
      row['startedAt'] is String &&
      (row['startedAt'] as String).isNotEmpty;

  Future<void> requestClose(Map<String, dynamic> row) async {
    if (busy || !eligible(row)) return;
    final pid = row['pid'] as int;
    final startedAt = row['startedAt'] as String;
    final name = row['name']?.toString() ?? '$pid';
    setState(() {
      busy = true;
      reviewing = true;
      error = null;
      receipt = null;
    });
    try {
      final preferences = CopyScope.of(context);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => CopyScope(
          preferences: preferences,
          child: AlertDialog(
            title: const UiText('Request graceful close?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$name · PID $pid'),
                  SelectableText(startedAt),
                  const SizedBox(height: 12),
                  const UiText(
                    'Save work first. The selected application may ask about unsaved work, decline, or remain open. This never forces termination.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const UiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const UiText('Request close'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || !mounted) return;
      setState(() => reviewing = false);
      final result = await widget.invoke('processes.stop', {
        'pid': pid,
        'startedAt': startedAt,
        'confirmed': true,
      });
      if (!mounted) return;
      if (result['pid'] != pid ||
          result['requested'] is! bool ||
          (result['requested'] == true &&
              (result['terminated'] != false ||
                  result['mode'] != 'CloseMainWindow'))) {
        throw const FormatException();
      }
      setState(() {
        receipt = result['requested'] == true
            ? 'Close requested. Process exit is not confirmed. Refresh to observe current records.'
            : 'No close request was accepted. The process may still be running.';
        // Require a new inventory before another mutation, including a declined request.
        records = null;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          records = null;
          error =
              'Close outcome is unavailable. Do not assume the process stopped. Refresh before another request.';
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          reviewing = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = (records ?? [])
        .where(
          (r) => '${r['name']} ${r['pid']}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Scaffold(
      appBar: inspectionAppBar(context, 'Processes'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const UiText('Inspect running processes'),
          const SizedBox(height: 8),
          const UiText(
            'Memory is a point-in-time working set. CPU time is cumulative, not current utilization. Records can change after collection.',
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: busy ? null : refresh,
              icon: const Icon(Icons.refresh),
              label: const UiText('Refresh processes'),
            ),
          ),
          const SizedBox(height: 16),
          SearchBar(
            hintText: localize(context, 'Filter by process name or PID'),
            leading: const Icon(Icons.search),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
          if (busy && !reviewing) const LinearProgressIndicator(),
          if ((busy && !reviewing) || error != null)
            OperationMotion(state: busy ? 'working' : 'error'),
          if (error != null) Semantics(liveRegion: true, child: UiText(error!)),
          if (receipt != null)
            Semantics(liveRegion: true, child: UiText(receipt!)),
          if (records == null && !busy && error == null && receipt == null)
            const UiText('No measured result yet. Start an operation above.'),
          if (records != null && visible.isEmpty)
            const UiText('No matching records.'),
          ...visible.map(
            (row) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['name'] ?? '—'} · PID ${row['pid'] ?? '—'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (row['workingSetBytes'] is num)
                      Text(
                        '${localize(context, 'Working set bytes')}: ${row['workingSetBytes']}',
                      ),
                    if (row['cpuTotalMilliseconds'] is num)
                      Text(
                        '${localize(context, 'Cumulative CPU milliseconds')}: ${row['cpuTotalMilliseconds']}',
                      ),
                    if (row['startedAt'] is String)
                      SelectableText(
                        '${localize(context, 'Started at UTC')}: ${row['startedAt']}',
                      ),
                    if (!eligible(row))
                      const UiText(
                        'Graceful close is unavailable for this record.',
                      ),
                    if (row['reason'] != null) Text(row['reason'].toString()),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: busy || !eligible(row)
                          ? null
                          : () => requestClose(row),
                      icon: const Icon(Icons.close),
                      label: const UiText('Request close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
