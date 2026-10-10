import 'package:flutter/material.dart';
import 'localization.dart';
import 'inspection_app_bar.dart';
import 'motion.dart';

typedef ServicesInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key, required this.invoke});
  final ServicesInvoke invoke;
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  bool busy = false;
  String query = '';
  String state = 'All states';
  String? error;
  List<Map<String, String>>? records;

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      records = null;
    });
    try {
      final result = await widget.invoke('services.list', {});
      if (result['available'] != true || result['canChange'] != false) {
        throw const FormatException();
      }
      // PowerShell serializes a single pipeline record as an object.
      final raw = result['records'];
      final items = raw == null
          ? <dynamic>[]
          : raw is List
          ? raw
          : [raw];
      if (items.length > 10000) throw const FormatException();
      final names = <String>{};
      final rows =
          items.map((item) {
            if (item is! Map) throw const FormatException();
            final row = <String, String>{};
            for (final key in ['Name', 'DisplayName', 'Status', 'StartType']) {
              final value = item[key];
              if (value is! String ||
                  value.isEmpty ||
                  value.length > 2048 ||
                  value.runes.any((c) => c < 32 || c == 127)) {
                throw const FormatException();
              }
              row[key] = value;
            }
            if (!names.add(row['Name']!.toLowerCase()))
              throw const FormatException();
            return row;
          }).toList()..sort(
            (a, b) =>
                a['Name']!.toLowerCase().compareTo(b['Name']!.toLowerCase()),
          );
      if (mounted) setState(() => records = rows);
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Service inventory is unavailable or invalid. No service was changed.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needle = query.toLowerCase();
    final visible = (records ?? [])
        .where(
          (r) =>
              (state == 'All states' || r['Status'] == state) &&
              r.values.any((v) => v.toLowerCase().contains(needle)),
        )
        .toList();
    return Scaffold(
      appBar: inspectionAppBar(context, 'Services'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              UiText(
                'Review local services',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const UiText(
                'Read service names, current states and configured start types. This workspace never starts, stops or reconfigures a service.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : refresh,
                    icon: const Icon(Icons.refresh),
                    label: const UiText('Read services'),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      isDense: false,
                      itemHeight: null,
                      initialValue: state,
                      decoration: InputDecoration(
                        labelText: localize(context, 'Service state'),
                        border: const OutlineInputBorder(),
                      ),
                      items: ['All states', 'Running', 'Stopped', 'Paused']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: UiText(s)),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => state = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SearchBar(
                leading: const Icon(Icons.search),
                hintText: localize(context, 'Filter loaded services'),
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
                  'No services collected. Start an explicit read above.',
                ),
              if (records != null) ...[
                const UiText(
                  'States can change after collection. Start type alone does not establish whether a service is needed or safe to disable.',
                ),
                Text(
                  '${localize(context, 'Matching loaded services')}: ${visible.length} / ${records!.length}',
                ),
                if (visible.isEmpty)
                  const UiText('No matching loaded services.'),
              ],
              ...visible.map(
                (row) => Card.outlined(
                  child: ExpansionTile(
                    key: ValueKey(row['Name']),
                    leading: const Icon(Icons.miscellaneous_services),
                    title: Text(row['DisplayName']!),
                    subtitle: Text('${row['Name']} · ${row['Status']}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SelectableText(
                              '${localize(context, 'Service name')}: ${row['Name']}',
                            ),
                            Text(
                              '${localize(context, 'Service state')}: ${row['Status']}',
                            ),
                            Text(
                              '${localize(context, 'Configured start type')}: ${row['StartType']}',
                            ),
                            const UiText(
                              'Read-only record. Refresh to obtain current state.',
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
                'Service names can contain local product details. Records remain transient and are not uploaded or automatically saved.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
