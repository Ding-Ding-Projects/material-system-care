import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'settings.dart';

void main() => runApp(const CareApp());

class Engine {
  static const channel = MethodChannel('material_system_care/engine');
  static Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> params,
  ) async {
    final raw = await channel.invokeMethod<Object?>('invoke', {
      'method': method,
      'params': params,
    });
    final dynamic envelope = raw is String ? jsonDecode(raw) : raw;
    if (envelope is! Map || envelope['ok'] != true) {
      final error = envelope is Map ? envelope['error'] : null;
      throw StateError(
        error is Map
            ? '${error['code']}: ${error['message']}'
            : 'The local engine returned an invalid response.',
      );
    }
    final result = envelope['result'];
    return result is Map
        ? Map<String, dynamic>.from(result)
        : {'items': result};
  }
}

class CareApp extends StatefulWidget {
  const CareApp({super.key});
  @override
  State<CareApp> createState() => _CareAppState();
}

class _CareAppState extends State<CareApp> {
  Map<String, dynamic> settings = {};
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await Engine.invoke('settings.get', {
        'key': 'workspacePreferences',
      });
      if (mounted && !saved.containsKey('items'))
        setState(() => settings = saved);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mode = settings['theme'] ?? 'system';
    final seed = Color(
      settings['seedColor'] is int ? settings['seedColor'] as int : 0xff33675c,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Material System Care',
      themeMode: mode == 'dark'
          ? ThemeMode.dark
          : mode == 'light'
          ? ThemeMode.light
          : ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        visualDensity: settings['density'] == 'compact'
            ? VisualDensity.compact
            : VisualDensity.standard,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: Workspace(
        settings: settings,
        changed: (value) => setState(() => settings = value),
      ),
    );
  }
}

const destinations = [
  'Overview',
  'Storage',
  'Apps',
  'Startup',
  'Protection',
  'Drivers',
  'Tools',
  'Activity',
  'Settings',
  'Help',
];
const cantonese = [
  '總覽',
  '儲存空間',
  '應用程式',
  '開機項目',
  '保護',
  '驅動程式',
  '工具',
  '操作記錄',
  '設定',
  '說明',
];
const destinationIcons = [
  Icons.monitor_heart_outlined,
  Icons.storage_outlined,
  Icons.apps_outlined,
  Icons.start_outlined,
  Icons.shield_outlined,
  Icons.memory_outlined,
  Icons.build_outlined,
  Icons.history,
  Icons.settings_outlined,
  Icons.help_outline,
];

class Workspace extends StatefulWidget {
  final Map<String, dynamic> settings;
  final ValueChanged<Map<String, dynamic>> changed;
  const Workspace({super.key, required this.settings, required this.changed});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int selected = 0;
  String name(int i) => widget.settings['language'] == 'yue'
      ? cantonese[i]
      : widget.settings['language'] == 'both'
      ? '${destinations[i]} · ${cantonese[i]}'
      : destinations[i];
  @override
  Widget build(BuildContext context) {
    final reduced =
        widget.settings['reducedMotion'] == true ||
        MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Material System Care'),
        actions: [
          IconButton(
            tooltip: 'Refresh workspace',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Help',
            onPressed: () => setState(() => selected = 9),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, bounds) => Row(
          children: [
            if (bounds.maxWidth >= 700)
              NavigationRail(
                extended: bounds.maxWidth >= 1150,
                selectedIndex: selected,
                onDestinationSelected: (i) => setState(() => selected = i),
                destinations: List.generate(
                  destinations.length,
                  (i) => NavigationRailDestination(
                    icon: Icon(destinationIcons[i]),
                    label: Text(name(i)),
                  ),
                ),
              ),
            if (bounds.maxWidth >= 700) const VerticalDivider(width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                child: Padding(
                  key: ValueKey(selected),
                  padding: const EdgeInsets.all(24),
                  child: selected == 8
                      ? SettingsPanel(
                          invoke: Engine.invoke,
                          onChanged: widget.changed,
                        )
                      : selected == 9
                      ? const HelpPanel()
                      : WorkflowPage(index: selected, title: name(selected)),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 700
          ? SafeArea(
              child: DropdownButtonFormField<int>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Workspace',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  destinations.length,
                  (i) => DropdownMenuItem(value: i, child: Text(name(i))),
                ),
                onChanged: (i) => setState(() => selected = i ?? 0),
              ),
            )
          : null,
    );
  }
}

class WorkflowPage extends StatefulWidget {
  final int index;
  final String title;
  const WorkflowPage({super.key, required this.index, required this.title});
  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? provenance;
  String? failure;
  bool busy = false;
  final input = TextEditingController();
  final search = TextEditingController();
  String query = '';
  bool regex = false;
  String? patternError;
  final Set<int> chosen = {};
  static const methods = [
    'system.snapshot',
    'storage.analyze',
    'apps.list',
    'startup.list',
    'security.status',
    'drivers.list',
    'network.diagnostics',
    'history.list',
  ];
  @override
  void initState() {
    super.initState();
    if (widget.index == 0)
      Engine.invoke('engine.ping', {})
          .then((value) {
            if (mounted) setState(() => provenance = value);
          })
          .catchError((Object _) {});
    if (widget.index != 1 && widget.index != 6) load();
  }

  @override
  void dispose() {
    input.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> load([String? method, Map<String, dynamic>? params]) async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final result = await Engine.invoke(
        method ?? methods[widget.index],
        params ?? {},
      );
      if (mounted)
        setState(() {
          data = result;
          chosen.clear();
        });
    } catch (e) {
      if (mounted)
        setState(
          () => failure = e is MissingPluginException
              ? 'The local engine is not connected. Start the installed application with its engine available, then retry.'
              : e.toString(),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Map<String, dynamic>> get rows {
    if (data == null) return [];
    for (final key in [
      'items',
      'files',
      'largeFiles',
      'groups',
      'targets',
      'receipts',
      'apps',
      'entries',
      'drivers',
      'packages',
      'records',
      'drives',
      'results',
      'services',
    ]) {
      final value = data![key];
      if (value is List)
        return value
            .map((e) => e is Map ? Map<String, dynamic>.from(e) : {'value': e})
            .toList();
    }
    return data!.entries
        .map((e) => {'property': e.key, 'value': e.value})
        .toList();
  }

  Future<bool> confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(detail)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm selected action'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> rowAction(String method, Map<String, dynamic> row) async {
    if (method == 'drivers.export') {
      final folder = await Engine.channel.invokeMethod<String>(
        'pickDirectory',
        {},
      );
      if (folder == null) return;
      row = {...row, 'destination': folder};
    }
    if (method == 'startup.set') {
      row = {...row, 'enabled': row['enabled'] != true};
    }
    if (!await confirm(
      'Review selected action',
      'Operation: $method\nTarget: ${row['name'] ?? row['path'] ?? row['id'] ?? 'Selected record'}\nOnly this selected target will be sent to the local engine.',
    ))
      return;
    await load(method, {
      ...row,
      if (method == 'cleanup.restore')
        'receiptId': row['receiptId'] ?? row['id'],
      'confirmed': true,
    });
  }

  String value(dynamic v) => v is Map || v is List
      ? const JsonEncoder.withIndent('  ').convert(v)
      : '$v';
  @override
  Widget build(BuildContext context) {
    final records = rows;
    final filtered = records.asMap().entries.where((e) {
      if (query.isEmpty) return true;
      final text = value(e.value);
      try {
        return regex
            ? RegExp(query, caseSensitive: false).hasMatch(text)
            : text.toLowerCase().contains(query.toLowerCase());
      } catch (_) {
        return false;
      }
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
        if (widget.index == 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Version: ${provenance?["manifest"]?["version"] ?? "build metadata unavailable"} · Updated at: provenance unavailable\nMeasurements below come from the local engine. No scan has permission to change files.',
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => widget.index == 1
                        ? load('storage.analyze', {'path': input.text})
                        : load(),
              icon: const Icon(Icons.refresh),
              label: Text(
                widget.index == 1 ? 'Analyze folder' : 'Refresh records',
              ),
            ),
            if (widget.index == 0)
              OutlinedButton.icon(
                onPressed: busy ? null : () => load('cleanup.scan', {}),
                icon: const Icon(Icons.manage_search),
                label: const Text('Scan recoverable cleanup'),
              ),
            if (widget.index == 1)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => load('storage.duplicates', {'path': input.text}),
                child: const Text('Find exact duplicates'),
              ),
            if (widget.index == 2)
              OutlinedButton(
                onPressed: busy ? null : () => load('apps.updates'),
                child: const Text('Check available updates'),
              ),
            if (widget.index == 4)
              FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () async {
                        if (await confirm(
                          'Start quick security scan?',
                          'Windows security will scan the local computer. Security settings remain enabled.',
                        ))
                          load('security.scan', {
                            'kind': 'quick',
                            'confirmed': true,
                          });
                      },
                child: const Text('Quick scan'),
              ),
            if (widget.index == 1)
              OutlinedButton(
                onPressed: busy ? null : () => load('cleanup.history'),
                child: const Text('Recovery history'),
              ),
            if (widget.index == 1)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final folder = await Engine.channel
                            .invokeMethod<String>('pickDirectory', {});
                        if (folder != null) setState(() => input.text = folder);
                      },
                icon: const Icon(Icons.folder_open),
                label: const Text('Choose folder'),
              ),
            if (data?['planId'] != null && data?['mutationPerformed'] == false)
              FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () async {
                        if (await confirm(
                          'Move approved temporary files to recovery?',
                          'The engine will revalidate this cleanup plan and move eligible aged temporary files into recoverable storage. Documents are excluded.',
                        ))
                          load('cleanup.apply', {
                            'planId': data!['planId'],
                            'confirmed': true,
                          });
                      },
                child: const Text('Apply reviewed cleanup plan'),
              ),
          ],
        ),
        if (widget.index == 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: input,
              decoration: const InputDecoration(
                labelText: 'Folder to analyze',
                hintText: r'C:\Users\Public',
                helperText:
                    'Enter a local folder. Analysis does not remove files.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        if (widget.index == 6) ToolsEditor(onRun: load, busy: busy),
        const SizedBox(height: 16),
        SearchBar(
          controller: search,
          hintText: 'Filter these records',
          leading: const Icon(Icons.search),
          onChanged: (v) => setState(() {
            query = v;
            try {
              if (regex) RegExp(v);
              patternError = null;
            } catch (e) {
              patternError = 'Invalid regular expression';
            }
          }),
          trailing: [
            MenuAnchor(
              builder: (context, controller, child) => IconButton(
                tooltip: 'Regular expression builder',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.data_object),
              ),
              menuChildren: [
                CheckboxMenuButton(
                  value: regex,
                  onChanged: (v) => setState(() => regex = v ?? false),
                  child: const Text('Use regular expression'),
                ),
                ...{
                  'Contains text': '.*text.*',
                  'Starts with': '^text',
                  'Ends with': r'text$',
                  'Digits': r'\d+',
                  'One of': '(first|second)',
                }.entries.map(
                  (e) => MenuItemButton(
                    onPressed: () {
                      search.text = e.value;
                      setState(() {
                        query = e.value;
                        regex = true;
                      });
                    },
                    child: Text(e.key),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (patternError != null)
          Text(
            patternError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        if (busy)
          const LinearProgressIndicator(
            semanticsLabel: 'Waiting for measured engine result',
          ),
        if (failure != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Operation unavailable'),
              subtitle: Text(failure!),
              trailing: TextButton(
                onPressed: busy ? null : load,
                child: const Text('Retry'),
              ),
            ),
          ),
        Expanded(
          child: data == null
              ? Center(
                  child: Text(
                    busy
                        ? 'Reading local records…'
                        : 'No measured result yet. Start an operation above.',
                  ),
                )
              : filtered.isEmpty
              ? const Center(child: Text('No matching records.'))
              : Scrollbar(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final entry = filtered[i];
                      final row = entry.value;
                      final title = value(
                        row['name'] ??
                            row['path'] ??
                            row['property'] ??
                            row['operation'] ??
                            row['id'] ??
                            'Record ${entry.key + 1}',
                      );
                      return CheckboxListTile(
                        value: chosen.contains(entry.key),
                        onChanged: (v) => setState(() {
                          if (v == true)
                            chosen.add(entry.key);
                          else
                            chosen.remove(entry.key);
                        }),
                        title: Text(title),
                        subtitle: SelectableText(
                          row.entries
                              .where((e) => e.key != 'name')
                              .map((e) => '${e.key}: ${value(e.value)}')
                              .join('\n'),
                        ),
                        secondary: PopupMenuButton<String>(
                          tooltip: 'Record actions',
                          onSelected: (method) => rowAction(method, row),
                          itemBuilder: (_) => [
                            if (widget.index == 2 && row['packageId'] is String)
                              const PopupMenuItem(
                                value: 'apps.uninstall',
                                child: Text('Uninstall selected app'),
                              ),
                            if (widget.index == 2 && row['packageId'] is String)
                              const PopupMenuItem(
                                value: 'apps.upgrade',
                                child: Text('Upgrade selected app'),
                              ),
                            if (widget.index == 3)
                              const PopupMenuItem(
                                value: 'startup.set',
                                child: Text('Change selected startup entry'),
                              ),
                            if (widget.index == 5)
                              const PopupMenuItem(
                                value: 'drivers.export',
                                child: Text('Export selected driver'),
                              ),
                            if (widget.index == 1 &&
                                (row.containsKey('receiptId') ||
                                    row.containsKey('planId')))
                              const PopupMenuItem(
                                value: 'cleanup.restore',
                                child: Text('Restore selected cleanup'),
                              ),
                            const PopupMenuItem(
                              enabled: false,
                              child: Text(
                                'Actions use the selected record only',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        Text(
          '${filtered.length} records · ${chosen.length} selected',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class ToolsEditor extends StatefulWidget {
  final Future<void> Function([String?, Map<String, dynamic>?]) onRun;
  final bool busy;
  const ToolsEditor({super.key, required this.onRun, required this.busy});
  @override
  State<ToolsEditor> createState() => _ToolsEditorState();
}

class _ToolsEditorState extends State<ToolsEditor> {
  int tool = 0;
  final path = TextEditingController();
  final destination = TextEditingController();
  String format = 'json-pretty';
  double length = 24;
  @override
  void dispose() {
    path.dispose();
    destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('File hash'),
              icon: Icon(Icons.fingerprint),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Convert file'),
              icon: Icon(Icons.transform),
            ),
            ButtonSegment(
              value: 2,
              label: Text('Password'),
              icon: Icon(Icons.key),
            ),
            ButtonSegment(
              value: 3,
              label: Text('Network'),
              icon: Icon(Icons.network_check),
            ),
          ],
          selected: {tool},
          onSelectionChanged: (v) => setState(() => tool = v.first),
        ),
        const SizedBox(height: 12),
        if (tool < 2)
          TextField(
            controller: path,
            decoration: const InputDecoration(
              labelText: 'Source file path',
              border: OutlineInputBorder(),
            ),
          ),
        if (tool == 1)
          TextField(
            controller: destination,
            decoration: const InputDecoration(
              labelText: 'Destination file path',
              helperText: 'Existing files are never silently overwritten.',
              border: OutlineInputBorder(),
            ),
          ),
        if (tool == 1)
          DropdownButtonFormField<String>(
            initialValue: format,
            decoration: const InputDecoration(labelText: 'Conversion'),
            items: const [
              DropdownMenuItem(
                value: 'json-pretty',
                child: Text('Format JSON'),
              ),
              DropdownMenuItem(
                value: 'json-compact',
                child: Text('Compact JSON'),
              ),
              DropdownMenuItem(
                value: 'utf-8',
                child: Text('Convert text to UTF-8'),
              ),
            ],
            onChanged: (v) => setState(() => format = v!),
          ),
        if (tool == 2)
          Slider(
            value: length,
            min: 12,
            max: 128,
            divisions: 116,
            label: '${length.round()} characters',
            onChanged: (v) => setState(() => length = v),
          ),
        if (tool == 2)
          const Text(
            'Generated locally. Passwords are not added to history or copied automatically.',
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: widget.busy
                ? null
                : () => widget.onRun(
                    [
                      'files.hash',
                      'files.convert',
                      'password.generate',
                      'network.diagnostics',
                    ][tool],
                    tool == 0
                        ? {'path': path.text, 'algorithm': 'SHA256'}
                        : tool == 1
                        ? {
                            'path': path.text,
                            'outputPath': destination.text,
                            'confirmed': true,
                            'format': format,
                          }
                        : tool == 2
                        ? {'length': length.round()}
                        : {},
                  ),
            child: Text(
              [
                'Calculate SHA-256',
                'Convert to new file',
                'Generate password',
                'Run network checks',
              ][tool],
            ),
          ),
        ),
      ],
    ),
  );
}

class HelpPanel extends StatelessWidget {
  const HelpPanel({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text(
        'Local maintenance guide',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const ExpansionTile(
        title: Text('Safe cleanup and recovery'),
        children: [
          ListTile(
            title: Text(
              'Analyze first, review selected files, and apply only a server-issued cleanup plan. Recovery history restores eligible moved files. No automatic document deletion is offered.',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('Apps, startup and drivers'),
        children: [
          ListTile(
            title: Text(
              'Select real records before changing them. Operations requiring administrator access report that requirement. Unsupported vendor capabilities remain unavailable.',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('Privacy and operation history'),
        children: [
          ListTile(
            title: Text(
              'Settings and operation receipts stay in local application data. Credentials and personal vocabulary are excluded from diagnostic exports and general history.',
            ),
          ),
        ],
      ),
      const ExpansionTile(
        title: Text('Keyboard and appearance'),
        children: [
          ListTile(
            title: Text(
              'Use Tab to move between controls, Space to select records, and Enter to activate focused actions. Settings provides language, theme and reduced-motion controls.',
            ),
          ),
        ],
      ),
    ],
  );
}
