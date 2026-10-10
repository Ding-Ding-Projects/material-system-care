import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'settings.dart';
import 'localization.dart';
import 'notifications.dart';
import 'provenance.dart';
import 'motion.dart';
import 'crash_diagnostics.dart';
import 'processes.dart';
import 'file_use.dart';
import 'scheduled_tasks.dart';
import 'frame_capture.dart';
import 'wording_cache.dart';

void main(List<String> arguments) {
  final capture = arguments
      .where((argument) => argument.startsWith('--capture-frame='))
      .toList();
  final diagnostics = arguments.contains('--diagnostics');
  final processes = arguments.contains('--processes');
  final fileUse = arguments.contains('--file-use');
  final scheduledTasks = arguments.contains('--scheduled-tasks');
  // Capture mode is explicit, starts at the selected real workspace, and
  // excludes persisted personal settings. It never injects diagnostic results.
  final exporting =
      [
            diagnostics,
            processes,
            fileUse,
            scheduledTasks,
          ].where((selected) => selected).length ==
          1 &&
      capture.length == 1;
  final app = CareApp(
    startDiagnostics: diagnostics,
    startProcesses: processes,
    startFileUse: fileUse,
    startScheduledTasks: scheduledTasks,
    isolatedCapture: exporting,
  );
  runApp(
    exporting
        ? FrameCapture(
            output: capture.single.substring('--capture-frame='.length),
            onInput: arguments.contains('--capture-on-input'),
            child: app,
          )
        : app,
  );
}

class Engine {
  static const channel = MethodChannel('material_system_care/engine');
  static int _requestSequence = 0;
  static String newRequestId() =>
      'ui-${DateTime.now().microsecondsSinceEpoch}-${++_requestSequence}';
  static Future<bool> cancel(String requestId) async =>
      await channel.invokeMethod<bool>('cancel', requestId) ?? false;
  static Future<Map<String, dynamic>> invoke(
    String method,
    Map<String, dynamic> params, {
    String? requestId,
  }) async {
    final raw = await channel.invokeMethod<Object?>('invoke', {
      'method': method,
      'params': params,
      if (requestId != null) 'id': requestId,
    });
    final dynamic envelope = raw is String ? jsonDecode(raw) : raw;
    if (envelope is! Map || envelope['ok'] != true) {
      final error = envelope is Map ? envelope['error'] : null;
      if (error is Map && error['code'] == 'CANCELLED')
        throw PlatformException(
          code: 'ENGINE_CANCELLED',
          message: 'Stopped waiting for scan.',
        );
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
  const CareApp({
    super.key,
    this.wordingCache,
    this.startDiagnostics = false,
    this.startProcesses = false,
    this.startFileUse = false,
    this.startScheduledTasks = false,
    this.isolatedCapture = false,
  });
  final WordingCache? wordingCache;
  final bool startDiagnostics;
  final bool startProcesses;
  final bool startFileUse;
  final bool startScheduledTasks;
  final bool isolatedCapture;
  @override
  State<CareApp> createState() => _CareAppState();
}

class _CareAppState extends State<CareApp> {
  Map<String, dynamic> settings = {};
  int _settingsRevision = 0;
  @override
  void initState() {
    super.initState();
    if (!widget.isolatedCapture) _restore();
  }

  Future<void> _restore() async {
    final revision = _settingsRevision;
    Map<String, String> wording = {};
    try {
      wording = await (widget.wordingCache ?? WordingCache.local()).load();
    } catch (_) {}
    if (mounted && revision == _settingsRevision)
      setState(() => settings = {...settings, 'privateVocabulary': wording});
    try {
      final saved = await Engine.invoke('settings.get', {
        'key': 'workspacePreferences',
      });
      if (mounted &&
          revision == _settingsRevision &&
          !saved.containsKey('items'))
        setState(() => settings = {...saved, 'privateVocabulary': wording});
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: ComposedTextScaler(
            MediaQuery.textScalerOf(context),
            (settings['textScale'] as num? ?? 1).toDouble().clamp(0.8, 2),
          ),
          disableAnimations:
              settings['reducedMotion'] == true ||
              MediaQuery.disableAnimationsOf(context),
        ),
        child: child!,
      ),
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
      home: CopyScope(
        preferences: settings,
        child: widget.startDiagnostics
            ? CrashDiagnosticsPage(invoke: Engine.invoke)
            : widget.startProcesses
            ? ProcessesPage(invoke: Engine.invoke)
            : widget.startFileUse
            ? FileUsePage(invoke: Engine.invoke)
            : widget.startScheduledTasks
            ? ScheduledTasksPage(invoke: Engine.invoke)
            : Workspace(
                settings: settings,
                wordingCache: widget.wordingCache,
                changed: (value) => setState(() {
                  _settingsRevision++;
                  settings = value;
                }),
              ),
      ),
    );
  }
}

final destinations = [
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
final cantonese = [
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
final destinationIcons = [
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
  final WordingCache? wordingCache;
  Workspace({
    super.key,
    required this.settings,
    required this.changed,
    this.wordingCache,
  });
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int selected = 0;
  String name(int i) => localize(context, destinations[i]);
  @override
  Widget build(BuildContext context) {
    final reduced =
        widget.settings['reducedMotion'] == true ||
        MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      endDrawer: NotificationPanel(),
      appBar: AppBar(
        title: UiText('Material System Care'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: localize(context, 'Notifications'),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: localize(context, 'Refresh workspace'),
            onPressed: () => setState(() {}),
            icon: Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: localize(context, 'Help'),
            onPressed: () => setState(() => selected = 9),
            icon: Icon(Icons.help_outline),
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
            if (bounds.maxWidth >= 700) VerticalDivider(width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: reduced ? Duration.zero : Duration(milliseconds: 250),
                child: Padding(
                  key: ValueKey(selected),
                  padding: EdgeInsets.all(24),
                  child: selected == 8
                      ? SettingsPanel(
                          wordingCache: widget.wordingCache,
                          invoke: Engine.invoke,
                          onChanged: widget.changed,
                        )
                      : selected == 9
                      ? HelpPanel()
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
                decoration: InputDecoration(
                  labelText: localize(context, 'Workspace'),
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
  WorkflowPage({super.key, required this.index, required this.title});
  @override
  State<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends State<WorkflowPage> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? provenance;
  String? failure;
  bool busy = false;
  String? activeReadId;
  bool cancelRequested = false;
  bool scanCancelled = false;
  static const cancellableReads = {
    'storage.analyze',
    'storage.duplicates',
    'cleanup.scan',
  };
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
    final id = activeReadId;
    if (id != null) Engine.cancel(id).catchError((Object _) => false);
    input.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> load([String? method, Map<String, dynamic>? params]) async {
    if (busy) return;
    final operation = method ?? methods[widget.index];
    final requestId = cancellableReads.contains(operation)
        ? Engine.newRequestId()
        : null;
    setState(() {
      busy = true;
      activeReadId = requestId;
      cancelRequested = false;
      scanCancelled = false;
      failure = null;
      if (method == 'apps.managed') {
        data = null;
        chosen.clear();
      }
    });
    try {
      final result = await Engine.invoke(
        operation,
        params ?? {},
        requestId: requestId,
      );
      if (method == 'apps.managed' && result['available'] != true) {
        throw StateError(
          result['reason']?.toString() ?? 'WinGet discovery is unavailable.',
        );
      }
      if (mounted)
        setState(() {
          data = result;
          failure = null;
          chosen.clear();
        });
      if (mounted && method != null)
        notifyOperation(context, 'success', method);
    } catch (e) {
      if (e is PlatformException &&
          e.code == 'ENGINE_CANCELLED' &&
          requestId != null) {
        if (mounted) {
          setState(() {
            scanCancelled = true;
            failure = null;
            data = null;
            chosen.clear();
          });
          notifyOperation(context, 'cancelled', operation);
        }
        return;
      }
      if (mounted)
        setState(
          () => failure = e is MissingPluginException
              ? 'The local engine is not connected. Start the installed application with its engine available, then retry.'
              : e.toString(),
        );
      if (mounted && method != null) notifyOperation(context, 'error', method);
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          activeReadId = null;
          cancelRequested = false;
        });
    }
  }

  Future<void> cancelRead() async {
    final id = activeReadId;
    if (!busy || id == null || cancelRequested) return;
    setState(() => cancelRequested = true);
    try {
      final accepted = await Engine.cancel(id);
      if (!accepted && mounted && activeReadId == id)
        setState(() {
          cancelRequested = false;
          failure =
              'Cancellation was not accepted. The scan may still be running.';
        });
    } catch (_) {
      if (mounted && activeReadId == id)
        setState(() {
          cancelRequested = false;
          failure =
              'Cancellation was not accepted. The scan may still be running.';
        });
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
        builder: (context) => CopyScope(
          preferences: CopyScope.of(this.context),
          child: AlertDialog(
            title: UiText(title),
            content: SingleChildScrollView(
              child: SelectableText(
                translations.containsKey(detail)
                    ? localize(this.context, detail)
                    : detail,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: UiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: UiText('Confirm selected action'),
              ),
            ],
          ),
        ),
      ) ??
      false;
  Future<void> rowAction(String method, Map<String, dynamic> row) async {
    if (busy) return;
    if (method == 'cleanup.restore') {
      final receiptId = row['receiptId'] ?? row['id'];
      setState(() {
        busy = true;
        failure = null;
      });
      Map<String, dynamic> details;
      try {
        details = await Engine.invoke('cleanup.details', {
          'receiptId': receiptId,
        });
        if (details['receiptId'] != receiptId || details['items'] is! List) {
          throw StateError('Recovery details are unavailable.');
        }
      } catch (error) {
        if (mounted) setState(() => failure = error.toString());
        return;
      } finally {
        if (mounted) setState(() => busy = false);
      }
      if (!mounted) return;
      final items = details['items'] as List;
      if (items.isEmpty) {
        setState(() => failure = 'This recovery record contains no files.');
        return;
      }
      final review =
          '${localize(context, "Review recorded files before restoration. Existing files will not be overwritten; availability is checked during restoration.")}\n\n${items.map((item) => '${item['path']}\n${localize(context, "Recorded state")}: ${item['state']}').join('\n\n')}';
      if (await confirm('Review recovery files', review)) {
        await load('cleanup.restore', {
          'receiptId': receiptId,
          'confirmed': true,
        });
      }
      return;
    }
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
      '${localize(context, "Operation")}: $method\n${localize(context, "Target")}: ${row['name'] ?? row['path'] ?? row['id'] ?? localize(context, "Selected record")}\n${localize(context, "Only this selected target will be sent to the local engine.")}',
    ))
      return;
    await load(method, {
      ...row,
      if (method == 'cleanup.restore')
        'receiptId': row['receiptId'] ?? row['id'],
      'confirmed': true,
    });
  }

  String value(dynamic v) => factualValue(v);
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
    return ListView(
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
        if (widget.index == 0)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: BuildProvenance(ping: provenance),
          ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (busy && activeReadId != null)
              OutlinedButton.icon(
                onPressed: cancelRequested ? null : cancelRead,
                icon: const Icon(Icons.stop_circle_outlined),
                label: UiText(
                  cancelRequested ? 'Cancellation requested…' : 'Cancel scan',
                ),
              ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => widget.index == 1
                        ? load('storage.analyze', {'path': input.text})
                        : load(),
              icon: Icon(Icons.refresh),
              label: UiText(
                widget.index == 1 ? 'Analyze folder' : 'Refresh records',
              ),
            ),
            if (widget.index == 0 || widget.index == 1)
              OutlinedButton.icon(
                onPressed: busy ? null : () => load('cleanup.scan', {}),
                icon: Icon(Icons.manage_search),
                label: UiText('Scan recoverable cleanup'),
              ),
            if (widget.index == 1)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => load('storage.duplicates', {'path': input.text}),
                child: UiText('Find exact duplicates'),
              ),
            if (widget.index == 2)
              OutlinedButton(
                onPressed: busy ? null : () => load('apps.updates'),
                child: UiText('Check available updates'),
              ),
            if (widget.index == 2)
              FilledButton.tonalIcon(
                onPressed: busy
                    ? null
                    : () async {
                        if (await confirm(
                          'Discover managed packages?',
                          'WinGet may contact its configured source to match installed packages. No packages will be changed, and new source agreements will not be accepted.',
                        )) {
                          await load('apps.managed');
                        }
                      },
                icon: const Icon(Icons.inventory_2_outlined),
                label: UiText('Discover WinGet packages'),
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
                child: UiText('Quick scan'),
              ),
            if (widget.index == 1)
              OutlinedButton(
                onPressed: busy ? null : () => load('cleanup.history'),
                child: UiText('Recovery history'),
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
                icon: Icon(Icons.folder_open),
                label: UiText('Choose folder'),
              ),
            if (data?['planId'] != null && data?['mutationPerformed'] == false)
              FilledButton.tonal(
                onPressed: busy || chosen.isEmpty
                    ? null
                    : () async {
                        final selected = chosen.toList()..sort();
                        final planId = data!['planId'];
                        final detail =
                            '${localize(context, "Only selected temporary files will move to recovery.")}\n\n${selected.map((i) => records[i]['path']).join('\n')}';
                        if (await confirm(
                          'Move selected temporary files to recovery?',
                          detail,
                        ))
                          load('cleanup.apply', {
                            'planId': planId,
                            'targetIndexes': selected,
                            'confirmed': true,
                          });
                      },
                child: UiText('Apply selected cleanup targets'),
              ),
            if (data?['planId'] != null && data?['mutationPerformed'] == false)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => setState(
                        () => chosen.addAll(filtered.map((entry) => entry.key)),
                      ),
                child: UiText('Select visible targets'),
              ),
            if (chosen.isNotEmpty)
              TextButton(
                onPressed: busy ? null : () => setState(chosen.clear),
                child: UiText('Clear selection'),
              ),
          ],
        ),
        if (widget.index == 1)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: TextField(
              controller: input,
              decoration: InputDecoration(
                labelText: localize(context, 'Folder to analyze'),
                hintText: r'C:\Users\Public',
                helperText: localize(
                  context,
                  'Enter a local folder. Analysis does not remove files.',
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        if (widget.index == 6)
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: ToolsEditor(onRun: load, busy: busy),
          ),
        SizedBox(height: 16),
        SearchBar(
          controller: search,
          hintText: localize(context, 'Filter these records'),
          leading: Icon(Icons.search),
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
                tooltip: localize(context, 'Regular expression builder'),
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: Icon(Icons.data_object),
              ),
              menuChildren: [
                CheckboxMenuButton(
                  value: regex,
                  onChanged: (v) => setState(() => regex = v ?? false),
                  child: UiText('Use regular expression'),
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
                    child: UiText(e.key),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (patternError != null)
          UiText(
            patternError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        SizedBox(height: 12),
        if (busy)
          LinearProgressIndicator(
            semanticsLabel: localize(
              context,
              'Waiting for measured engine result',
            ),
          ),
        OperationMotion(
          state: busy
              ? 'working'
              : scanCancelled
              ? 'cancelled'
              : failure != null
              ? 'error'
              : data != null
              ? 'success'
              : 'idle',
        ),
        if (failure != null)
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: Icon(Icons.error_outline),
              title: UiText('Operation unavailable'),
              subtitle: SelectableText(
                translations.containsKey(failure)
                    ? localize(context, failure!)
                    : failure!,
              ),
              trailing: TextButton(
                onPressed: busy ? null : load,
                child: UiText('Retry'),
              ),
            ),
          ),
        if (widget.index == 2 && data?['limitation'] is String)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: UiText(data!['limitation'] as String),
          ),
        SizedBox(
          height: 360,
          child: data == null
              ? Center(
                  child: UiText(
                    busy
                        ? 'Reading local records…'
                        : 'No measured result yet. Start an operation above.',
                  ),
                )
              : filtered.isEmpty
              ? Center(child: UiText('No matching records.'))
              : Scrollbar(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1),
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
                        title: Text(
                          row.containsKey('property')
                              ? localize(context, title)
                              : title,
                        ),
                        subtitle: SelectableText(
                          row.entries
                              .where((e) => e.key != 'name')
                              .map(
                                (e) =>
                                    '${localize(context, e.key)}: ${value(e.value)}',
                              )
                              .join('\n'),
                        ),
                        secondary: PopupMenuButton<String>(
                          tooltip: localize(context, 'Record actions'),
                          onSelected: (method) => rowAction(method, row),
                          itemBuilder: (_) => [
                            if (widget.index == 2 && row['packageId'] is String)
                              PopupMenuItem(
                                value: 'apps.uninstall',
                                child: UiText('Uninstall selected app'),
                              ),
                            if (widget.index == 2 && row['packageId'] is String)
                              PopupMenuItem(
                                value: 'apps.upgrade',
                                child: UiText('Upgrade selected app'),
                              ),
                            if (widget.index == 3)
                              PopupMenuItem(
                                value: 'startup.set',
                                child: UiText('Change selected startup entry'),
                              ),
                            if (widget.index == 5)
                              PopupMenuItem(
                                value: 'drivers.export',
                                child: UiText('Export selected driver'),
                              ),
                            if (widget.index == 1 &&
                                (row.containsKey('receiptId') ||
                                    row.containsKey('planId')))
                              PopupMenuItem(
                                value: 'cleanup.restore',
                                child: UiText('Restore selected cleanup'),
                              ),
                            PopupMenuItem(
                              enabled: false,
                              child: UiText(
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
          '${filtered.length} ${localize(context, "records")} · ${chosen.length} ${localize(context, "selected")}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class ToolsEditor extends StatefulWidget {
  final Future<void> Function([String?, Map<String, dynamic>?]) onRun;
  final bool busy;
  ToolsEditor({super.key, required this.onRun, required this.busy});
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
    padding: EdgeInsets.only(top: 12),
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: widget.busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CopyScope(
                        preferences: CopyScope.of(context),
                        child: CrashDiagnosticsPage(invoke: Engine.invoke),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.monitor_heart_outlined),
            label: UiText('Blue-screen diagnostics'),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: widget.busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CopyScope(
                        preferences: CopyScope.of(context),
                        child: ProcessesPage(invoke: Engine.invoke),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.memory),
            label: const UiText('Processes'),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: widget.busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CopyScope(
                        preferences: CopyScope.of(context),
                        child: FileUsePage(invoke: Engine.invoke),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.find_in_page_outlined),
            label: const UiText('File use'),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: widget.busy
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CopyScope(
                        preferences: CopyScope.of(context),
                        child: ScheduledTasksPage(invoke: Engine.invoke),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.schedule),
            label: const UiText('Scheduled tasks'),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(
              value: 0,
              label: UiText('File hash'),
              icon: Icon(Icons.fingerprint),
            ),
            ButtonSegment(
              value: 1,
              label: UiText('Convert file'),
              icon: Icon(Icons.transform),
            ),
            ButtonSegment(
              value: 2,
              label: UiText('Password'),
              icon: Icon(Icons.key),
            ),
            ButtonSegment(
              value: 3,
              label: UiText('Network'),
              icon: Icon(Icons.network_check),
            ),
          ],
          selected: {tool},
          onSelectionChanged: (v) => setState(() => tool = v.first),
        ),
        SizedBox(height: 12),
        if (tool < 2)
          TextField(
            controller: path,
            decoration: InputDecoration(
              labelText: localize(context, 'Source file path'),
              border: OutlineInputBorder(),
            ),
          ),
        if (tool == 1)
          TextField(
            controller: destination,
            decoration: InputDecoration(
              labelText: localize(context, 'Destination file path'),
              helperText: localize(
                context,
                'Existing files are never silently overwritten.',
              ),
              border: OutlineInputBorder(),
            ),
          ),
        if (tool == 1)
          DropdownButtonFormField<String>(
            initialValue: format,
            decoration: InputDecoration(
              labelText: localize(context, 'Conversion'),
            ),
            items: [
              DropdownMenuItem(
                value: 'json-pretty',
                child: UiText('Format JSON'),
              ),
              DropdownMenuItem(
                value: 'json-compact',
                child: UiText('Compact JSON'),
              ),
              DropdownMenuItem(
                value: 'utf-8',
                child: UiText('Convert text to UTF-8'),
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
            label: '${length.round()} ${localize(context, "characters")}',
            onChanged: (v) => setState(() => length = v),
          ),
        if (tool == 2)
          UiText(
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
            child: UiText(
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
  HelpPanel({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      UiText(
        'Local maintenance guide',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      ExpansionTile(
        title: UiText('Safe cleanup and recovery'),
        children: [
          ListTile(
            title: UiText(
              'Analyze first, review selected files, and apply only a server-issued cleanup plan. Recovery history restores eligible moved files. No automatic document deletion is offered.',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: UiText('Apps, startup and drivers'),
        children: [
          ListTile(
            title: UiText(
              'Select real records before changing them. Operations requiring administrator access report that requirement. Unsupported vendor capabilities remain unavailable.',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: UiText('Privacy and operation history'),
        children: [
          ListTile(
            title: UiText(
              'Settings and operation receipts stay in local application data. Credentials and personal vocabulary are excluded from diagnostic exports and general history.',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: UiText('Keyboard and appearance'),
        children: [
          ListTile(
            title: UiText(
              'Use Tab to move between controls, Space to select records, and Enter to activate focused actions. Settings provides language, theme and reduced-motion controls.',
            ),
          ),
        ],
      ),
    ],
  );
}

/// Custom scaling multiplies the platform's final scaled font size, preserving
/// nonlinear accessibility behavior. A factor of one is an exact pass-through.
class ComposedTextScaler extends TextScaler {
  const ComposedTextScaler(this.platform, this.factor);
  final TextScaler platform;
  final double factor;
  @override
  double scale(double fontSize) => platform.scale(fontSize) * factor;
  @override
  double get textScaleFactor => platform.scale(14) / 14 * factor;
  @override
  bool operator ==(Object other) =>
      other is ComposedTextScaler &&
      other.platform == platform &&
      other.factor == factor;
  @override
  int get hashCode => Object.hash(platform, factor);
}

/// Factual engine values deliberately bypass localization and personal wording.
String factualValue(Object? value) => value is Map || value is List
    ? const JsonEncoder.withIndent('  ').convert(value)
    : '$value';
