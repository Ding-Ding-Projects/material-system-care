import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'localization.dart';
import 'inspection_app_bar.dart';
import 'motion.dart';

typedef DiagnosticInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

/// Read-only evidence workspace. It never uploads dumps or starts repairs.
class CrashDiagnosticsPage extends StatefulWidget {
  const CrashDiagnosticsPage({super.key, required this.invoke});
  final DiagnosticInvoke invoke;
  @override
  State<CrashDiagnosticsPage> createState() => _CrashDiagnosticsPageState();
}

class _CrashDiagnosticsPageState extends State<CrashDiagnosticsPage> {
  final code = TextEditingController();
  int days = 30;
  bool busy = false;
  String? error;
  Map<String, dynamic>? report;
  Map<String, dynamic>? explanation;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> run(bool collect) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      if (collect) {
        report = null;
      } else {
        explanation = null;
      }
    });
    try {
      final result = await widget.invoke(
        collect ? 'diagnostics.crashes' : 'diagnostics.explainStopCode',
        collect ? {'days': days, 'limit': 50} : {'code': code.text.trim()},
      );
      if (!mounted) return;
      setState(() {
        if (collect) {
          report = result;
        } else {
          explanation = result;
        }
      });
    } catch (failure) {
      final text = failure is StateError ? failure.message.toString() : '';
      final reason = failure is MissingPluginException
          ? 'The local engine connection is unavailable.'
          : text.contains('OPERATION_TIMEOUT:')
          ? 'Crash collection exceeded fifteen seconds. Try a shorter period.'
          : text.contains('RESULT_TOO_LARGE:')
          ? 'Crash evidence exceeded the output limit. Choose a shorter period.'
          : text.contains('PLATFORM_UNSUPPORTED:')
          ? 'Crash event collection requires Windows.'
          : text.contains('INVALID_PARAMETERS:')
          ? 'Enter a valid hexadecimal stop code or unsigned decimal number.'
          : text.contains('EVENT_LOG_UNAVAILABLE:')
          ? 'Crash evidence could not be read. No permissions were changed. Try again or check Event Viewer.'
          : 'The local diagnostic request could not complete. Reconnect the engine and try again.';
      if (mounted) setState(() => error = reason);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget explanationTile(Map value) => ListTile(
    isThreeLine: true,
    leading: const Icon(Icons.info_outline),
    title: Text('${value['hex']} · ${value['name']}'),
    subtitle: UiText(
      'A stop code describes a condition, not a confirmed cause.',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final events = (report?['events'] as List?) ?? [];
    final dumps = (report?['dumps'] as List?) ?? [];
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        CopyScope.of(context)['reducedMotion'] == true;
    return Scaffold(
      appBar: inspectionAppBar(context, 'Blue-screen diagnostics'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              UiText(
                'Investigate a crash',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              UiText(
                'Read local crash events and dump metadata. Dump contents stay untouched. Nothing is uploaded or repaired.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      isDense: false,
                      itemHeight: null,
                      initialValue: days,
                      decoration: InputDecoration(
                        labelText: localize(context, 'Event lookback'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [7, 30, 90, 365]
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: UiText('$n days'),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              days = value!;
                              report = null;
                            }),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : () => run(true),
                    icon: const Icon(Icons.manage_search),
                    label: UiText('Read crash evidence'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: code,
                      enabled: !busy,
                      maxLength: 16,
                      onChanged: (_) {
                        if (explanation != null)
                          setState(() => explanation = null);
                      },
                      onSubmitted: (_) => run(false),
                      decoration: InputDecoration(
                        labelText: localize(context, 'Stop code'),
                        hintText: '0x0000009F',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => run(false),
                    icon: const Icon(Icons.search),
                    label: UiText('Explain stop code'),
                  ),
                ],
              ),
              OperationMotion(
                state: busy
                    ? 'working'
                    : error != null
                    ? 'error'
                    : report != null || explanation != null
                    ? 'complete'
                    : 'idle',
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: UiText(error!),
                  ),
                ),
              AnimatedSize(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: explanation == null
                    ? const SizedBox.shrink()
                    : Card.outlined(child: explanationTile(explanation!)),
              ),
              if (report != null) ...[
                const SizedBox(height: 16),
                UiText(
                  'Recorded events',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (report?['eventsTruncated'] == true)
                  ListTile(
                    leading: const Icon(Icons.more_time),
                    title: UiText(
                      'Only the newest 50 matching events are shown. Choose a shorter period to narrow the result.',
                    ),
                  ),
                UiText(
                  'Event times can follow the crash or restart. An unexpected restart alone does not prove a blue screen.',
                ),
                if (events.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.event_available),
                    title: UiText('No matching events in this period.'),
                    subtitle: UiText(
                      'This does not rule out a crash. Event records may be unavailable or cleared.',
                    ),
                  ),
                ...events.whereType<Map>().map(
                  (event) => Card.outlined(
                    child: ExpansionTile(
                      leading: Icon(
                        event['stopCode'] is Map
                            ? Icons.monitor_heart_outlined
                            : Icons.restart_alt,
                      ),
                      title: UiText(
                        event['stopCode'] is Map
                            ? 'Stop code recorded'
                            : event['eventId'] == 1001
                            ? 'Crash report without a readable code'
                            : 'Unexpected restart',
                      ),
                      subtitle: Text(
                        '${event['recordedAt'] ?? localize(context, 'Time unavailable')} · ${localize(context, 'Record')} ${event['recordId'] ?? "?"}',
                      ),
                      children: [
                        ListTile(
                          title: Text('${event['provider']}'),
                          subtitle: Text(
                            '${localize(context, 'Event')} ${event['eventId']}',
                          ),
                        ),
                        if (event['stopCode'] is Map)
                          explanationTile(event['stopCode'] as Map),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                UiText(
                  'Available dump metadata',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (dumps.isEmpty)
                  ListTile(title: UiText('No accessible dump files found.')),
                ...dumps.whereType<Map>().map(
                  (dump) => ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text('${dump['name']}'),
                    subtitle: Text(
                      '${dump['bytes']} ${localize(context, 'bytes')} · ${dump['modifiedAt']}',
                    ),
                    trailing: Tooltip(
                      message: localize(context, 'Metadata only'),
                      child: const Icon(Icons.lock_outline),
                    ),
                  ),
                ),
                ...((report?['warnings'] as List?) ?? [])
                    .whereType<String>()
                    .map(
                      (warning) => ListTile(
                        leading: const Icon(Icons.warning_amber),
                        title: UiText(warning),
                      ),
                    ),
              ],
              const Divider(height: 32),
              UiText(
                'Next checks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              UiText(
                'Compare recent driver, firmware, hardware, and Windows updates. Preserve dump files before changing anything. Use Microsoft WinDbg with matching symbols for deeper analysis.',
              ),
              const SizedBox(height: 12),
              UiText(
                'This workspace does not analyze stacks or symbols, identify a culprit driver, change drivers, or restart Windows.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
