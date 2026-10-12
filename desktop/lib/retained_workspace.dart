import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'localization.dart';
import 'notifications.dart';
import 'shell_elements.dart';
import 'workspace_tabs.dart';

typedef WorkspaceInvoke =
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>);

class RetainedWorkspace extends StatefulWidget {
  const RetainedWorkspace({
    super.key,
    required this.invoke,
    required this.page,
  });
  final WorkspaceInvoke invoke;
  final Widget Function(BuildContext, String) page;
  @override
  State<RetainedWorkspace> createState() => _RetainedWorkspaceState();
}

const workspaceLabels = <String, String>{
  'overview': 'Overview',
  'cleanup': 'Recoverable cleanup',
  'storage': 'Storage analysis',
  'duplicates': 'Duplicate files',
  'apps': 'Apps',
  'startup': 'Startup',
  'protection': 'Protection status',
  'drivers': 'Driver inventory',
  'tools': 'Tools',
  'activity': 'Activity',
  'settings': 'Settings',
  'help': 'Help',
  'processes': 'Processes',
  'services': 'Services',
  'tasks': 'Scheduled tasks',
  'diagnostics': 'Blue-screen diagnostics',
  'file-use': 'File use',
};

class _RetainedWorkspaceState extends State<RetainedWorkspace> {
  static const window = MethodChannel('material_system_care/window');
  WorkspaceTabs state = WorkspaceTabs.initial();
  int revision = 0;
  int serial = 0;
  bool maximized = false;
  String query = '';
  String? persistenceError;
  String? windowError;
  bool saving = false;
  bool closingReview = false;
  final search = TextEditingController();
  final launcher = MenuController();
  final collapsed = <String>{};
  Future<void> saveQueue = Future.value();

  @override
  void initState() {
    super.initState();
    window.setMethodCallHandler((call) async {
      if (call.method == 'closeRequested') await windowAction('close');
      if (call.method == 'stateChanged') await refreshWindow();
    });
    window
        .invokeMethod<void>('claimShell')
        .then((_) => refreshWindow())
        .catchError((Object _) {
          if (mounted)
            setState(
              () => windowError = 'The native window action is unavailable.',
            );
        });
    restore();
  }

  @override
  void dispose() {
    window.invokeMethod<void>('releaseShell').catchError((Object _) {});
    window.setMethodCallHandler(null);
    search.dispose();
    super.dispose();
  }

  Future<void> refreshWindow() async {
    try {
      final data = await window.invokeMapMethod<String, dynamic>('state');
      if (mounted) setState(() => maximized = data?['maximized'] == true);
    } catch (_) {}
  }

  Future<void> restore() async {
    final started = revision;
    try {
      final response = await widget.invoke('settings.get', {
        'key': 'workspaceTabs',
      });
      final value = response.containsKey('value')
          ? response['value']
          : response;
      if (value == null || (value is Map && value.isEmpty)) return;
      final loaded = WorkspaceTabs.parse(value);
      if (mounted && revision == started) setState(() => state = loaded);
    } catch (_) {
      if (mounted && revision == started)
        setState(
          () => persistenceError =
              'Saved tabs could not be loaded. The current session remains available.',
        );
    }
  }

  void change(WorkspaceTabs next) {
    setState(() {
      state = next;
      revision++;
      saving = true;
      persistenceError = null;
    });
    final snapshot = next.toJson();
    final ownedRevision = revision;
    saveQueue = saveQueue.then((_) async {
      try {
        await widget.invoke('settings.save', {
          'key': 'workspaceTabs',
          'value': snapshot,
        });
        if (mounted && revision == ownedRevision)
          setState(() {
            saving = false;
            persistenceError = null;
          });
      } catch (_) {
        if (mounted && revision == ownedRevision)
          setState(() {
            saving = false;
            persistenceError =
                'Tabs were not saved. Retry saving the current session.';
          });
      }
    });
  }

  void open(String route) {
    final found = state.tabs.where((t) => t.route == route);
    if (found.isNotEmpty) {
      activateTab(found.first.id);
      return;
    }
    if (state.tabs.length >= 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: UiText('Close a workspace tab before opening another.'),
        ),
      );
      return;
    }
    final id = '$route-${DateTime.now().microsecondsSinceEpoch}-${++serial}';
    change(
      WorkspaceTabs(
        tabs: [
          ...state.tabs,
          WorkspaceTab(id: id, route: route),
        ],
        active: id,
        dock: state.dock,
      ),
    );
  }

  void activateTab(String id) =>
      change(WorkspaceTabs(tabs: state.tabs, active: id, dock: state.dock));

  Future<bool> confirmClose(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: UiText(title),
          content: const UiText(
            'Closing discards this session’s selections and review. A running request may still be finishing in the local engine. Keep the workspace open to inspect its outcome.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const UiText('Keep open'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const UiText('Close'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> tabAction(WorkspaceTab tab, String action) async {
    if (action == 'close') {
      if (tab.pinned ||
          state.tabs.length == 1 ||
          !await confirmClose('Close workspace?') ||
          !mounted)
        return;
      final remaining = state.tabs.where((t) => t.id != tab.id).toList();
      change(
        WorkspaceTabs(
          tabs: remaining,
          active: state.active == tab.id ? remaining.first.id : state.active,
          dock: state.dock,
        ),
      );
    } else if (action == 'pin') {
      change(
        WorkspaceTabs(
          tabs: state.tabs
              .map((t) => t.id == tab.id ? t.copy(pinned: !t.pinned) : t)
              .toList(),
          active: state.active,
          dock: state.dock,
        ),
      );
    } else if (action == 'group') {
      final input = TextEditingController(text: tab.group);
      final group = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const UiText('Tab group'),
          content: TextField(
            controller: input,
            maxLength: 48,
            decoration: InputDecoration(
              labelText: localize(context, 'Group name'),
              helperText: localize(context, 'Leave empty to remove the group.'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input.text.trim()),
              child: const UiText('Save'),
            ),
          ],
        ),
      );
      input.dispose();
      if (group != null && mounted && !RegExp(r'[\x00-\x1f]').hasMatch(group))
        change(
          WorkspaceTabs(
            tabs: state.tabs
                .map((t) => t.id == tab.id ? t.copy(group: group) : t)
                .toList(),
            active: state.active,
            dock: state.dock,
          ),
        );
    } else if (action == 'earlier' || action == 'later') {
      final tabs = [...state.tabs];
      final i = tabs.indexWhere((t) => t.id == tab.id);
      final j = i + (action == 'earlier' ? -1 : 1);
      if (i >= 0 && j >= 0 && j < tabs.length) {
        final item = tabs.removeAt(i);
        tabs.insert(j, item);
        change(
          WorkspaceTabs(tabs: tabs, active: state.active, dock: state.dock),
        );
      }
    }
  }

  Future<void> windowAction(String method) async {
    if (method == 'close') {
      if (closingReview) return;
      closingReview = true;
      final approved = await confirmClose('Close application?');
      closingReview = false;
      if (!approved || !mounted) return;
    }
    try {
      await window.invokeMethod<void>(method);
      await refreshWindow();
    } catch (_) {
      if (mounted)
        setState(
          () => windowError = 'The native window action is unavailable.',
        );
    }
  }

  void help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const UiText('Workspace help'),
      content: const SingleChildScrollView(
        child: UiText(
          'Open a dedicated task from the workspace menu. Tabs keep live filters, selections and reviews while this session is open. Saved tabs restore navigation only after restart, never an old operation or cleanup plan. Pin a tab to protect it from closing. Groups organize tabs; use their heading to collapse the list. Caption controls act on this application only. Double-click the title to maximize or restore, and right-click it for the native window menu.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const UiText('Close'),
        ),
      ],
    ),
  );

  Widget caption() => RegisteredElement(
    id: 'shell.chrome.surface',
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.health_and_safety_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => windowAction('drag'),
                onDoubleTap: () => windowAction('toggleMaximize'),
                onSecondaryTap: () => windowAction('systemMenu'),
                child: RegisteredElement(
                  id: 'shell.chrome.title',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      localize(context, 'Material System Care'),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
            RegisteredElement(
              id: 'shell.help',
              child: IconButton(
                tooltip: localize(context, 'Workspace help'),
                onPressed: help,
                icon: const Icon(Icons.help_outline),
              ),
            ),
            RegisteredElement(
              id: 'shell.notifications',
              child: Builder(
                builder: (context) => IconButton(
                  tooltip: localize(context, 'Notifications'),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  icon: const Icon(Icons.notifications_outlined),
                ),
              ),
            ),
            RegisteredElement(
              id: 'shell.chrome.minimize',
              child: IconButton(
                tooltip: localize(context, 'Minimize'),
                onPressed: () => windowAction('minimize'),
                icon: const Icon(Icons.remove),
              ),
            ),
            RegisteredElement(
              id: 'shell.chrome.maximize',
              child: IconButton(
                tooltip: localize(
                  context,
                  maximized ? 'Restore window' : 'Maximize',
                ),
                onPressed: () => windowAction('toggleMaximize'),
                icon: Icon(maximized ? Icons.filter_none : Icons.crop_square),
              ),
            ),
            RegisteredElement(
              id: 'shell.chrome.close',
              child: IconButton(
                tooltip: localize(context, 'Close application'),
                onPressed: () => windowAction('close'),
                icon: const Icon(Icons.close),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ),
  );

  Widget tabItem(WorkspaceTab tab) => RegisteredElement(
    id: 'shell.tabs.item',
    child: ListTile(
      key: ValueKey('tab-${tab.id}'),
      selected: state.active == tab.id,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      title: Text(
        localize(context, workspaceLabels[tab.route]!),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      leading: Icon(tab.pinned ? Icons.push_pin_outlined : Icons.tab, size: 20),
      onTap: () => activateTab(tab.id),
      trailing: RegisteredElement(
        id: 'shell.tabs.context',
        child: PopupMenuButton<String>(
          tooltip: localize(context, 'Tab actions'),
          onSelected: (a) => tabAction(tab, a),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'pin',
              child: UiText(tab.pinned ? 'Unpin tab' : 'Pin tab'),
            ),
            const PopupMenuItem(value: 'group', child: UiText('Tab group')),
            const PopupMenuItem(
              value: 'earlier',
              child: UiText('Move earlier'),
            ),
            const PopupMenuItem(value: 'later', child: UiText('Move later')),
            PopupMenuItem(
              value: 'close',
              enabled: !tab.pinned && state.tabs.length > 1,
              child: const UiText('Close workspace'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget strip(bool vertical) {
    final visible = state.tabs
        .where(
          (t) => '${workspaceLabels[t.route]} ${t.group}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    final items = <Widget>[];
    final groups = <String>{};
    for (final tab in visible) {
      if (tab.group.isNotEmpty && groups.add(tab.group))
        items.add(
          ListTile(
            title: Text(
              tab.group,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: Icon(
              collapsed.contains(tab.group)
                  ? Icons.chevron_right
                  : Icons.expand_more,
            ),
            onTap: () => setState(() {
              if (!collapsed.add(tab.group)) collapsed.remove(tab.group);
            }),
          ),
        );
      if (!collapsed.contains(tab.group)) items.add(tabItem(tab));
    }
    final controls = Row(
      children: [
        Expanded(
          child: RegisteredElement(
            id: 'shell.launcher',
            child: MenuAnchor(
              controller: launcher,
              menuChildren: workspaceLabels.entries
                  .map(
                    (entry) => MenuItemButton(
                      onPressed: () => open(entry.key),
                      child: UiText(entry.value),
                    ),
                  )
                  .toList(),
              builder: (_, controller, child) => FilledButton.tonalIcon(
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.add),
                label: const UiText('Open workspace'),
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: localize(context, 'Dock tabs'),
          onSelected: (dock) => change(
            WorkspaceTabs(tabs: state.tabs, active: state.active, dock: dock),
          ),
          itemBuilder: (_) => ['left', 'right', 'top', 'bottom']
              .map(
                (dock) =>
                    PopupMenuItem(value: dock, child: UiText('Dock $dock')),
              )
              .toList(),
        ),
      ],
    );
    final filter = RegisteredElement(
      id: 'shell.tabs.search',
      child: TextField(
        controller: search,
        onChanged: (text) => setState(() => query = text),
        decoration: InputDecoration(
          labelText: localize(context, 'Find tabs'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: localize(context, 'Clear search'),
            onPressed: () {
              search.clear();
              setState(() => query = '');
            },
            icon: const Icon(Icons.close),
          ),
        ),
      ),
    );
    return RegisteredElement(
      id: 'shell.tabs.strip',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: vertical
            ? SizedBox(
                width: 240,
                child: Column(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: controls),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: filter,
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: UiText('No matching tabs.'))
                          : ListView(children: items),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: 150,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          SizedBox(width: 240, child: controls),
                          const SizedBox(width: 16),
                          Expanded(child: filter),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: items
                            .map((item) => SizedBox(width: 250, child: item))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vertical = state.dock == 'left' || state.dock == 'right';
    final content = Expanded(
      key: const ValueKey('retained-workspace-content'),
      child: RegisteredElement(
        id: 'shell.content',
        child: IndexedStack(
          index: state.tabs.indexWhere((t) => t.id == state.active),
          children: state.tabs
              .map(
                (tab) => KeyedSubtree(
                  key: ValueKey('page-${tab.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: widget.page(context, tab.route),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    final tabStrip = KeyedSubtree(
      key: const ValueKey('retained-workspace-tabs'),
      child: strip(vertical),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () =>
            launcher.open(),
        const SingleActivator(LogicalKeyboardKey.f1): help,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          endDrawer: const NotificationPanel(),
          body: Column(
            children: [
              caption(),
              if (persistenceError != null || windowError != null)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: UiText(persistenceError ?? windowError!),
                    trailing: persistenceError == null
                        ? IconButton(
                            tooltip: localize(context, 'Close'),
                            onPressed: () => setState(() => windowError = null),
                            icon: const Icon(Icons.close),
                          )
                        : TextButton(
                            onPressed: () => change(state),
                            child: const UiText('Retry saving'),
                          ),
                  ),
                ),
              if (saving) const LinearProgressIndicator(),
              Expanded(
                key: const ValueKey('retained-workspace-layout'),
                child: Flex(
                  direction: vertical ? Axis.horizontal : Axis.vertical,
                  children: [
                    if (state.dock == 'left' || state.dock == 'top') tabStrip,
                    content,
                    if (state.dock == 'right' || state.dock == 'bottom')
                      tabStrip,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
