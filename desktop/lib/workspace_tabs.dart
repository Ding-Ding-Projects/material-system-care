/// Persistence contains bounded routing metadata only, never engine records,
/// selected paths, operation receipts, or personal wording.
class WorkspaceTab {
  const WorkspaceTab({
    required this.id,
    required this.route,
    this.pinned = false,
    this.group = '',
  });
  final String id, route, group;
  final bool pinned;
  WorkspaceTab copy({bool? pinned, String? group}) => WorkspaceTab(
    id: id,
    route: route,
    pinned: pinned ?? this.pinned,
    group: group ?? this.group,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'route': route,
    'pinned': pinned,
    'group': group,
  };
}

class WorkspaceTabs {
  WorkspaceTabs({required this.tabs, required this.active, this.dock = 'left'});
  final List<WorkspaceTab> tabs;
  final String active, dock;
  static const routes = {
    'overview',
    'cleanup',
    'storage',
    'duplicates',
    'apps',
    'startup',
    'protection',
    'drivers',
    'tools',
    'activity',
    'settings',
    'help',
    'processes',
    'services',
    'tasks',
    'diagnostics',
    'file-use',
  };
  static WorkspaceTabs initial() => WorkspaceTabs(
    tabs: [const WorkspaceTab(id: 'overview', route: 'overview', pinned: true)],
    active: 'overview',
  );
  static WorkspaceTabs parse(dynamic value) {
    if (value is! Map || value['version'] != 1 || value['tabs'] is! List)
      throw const FormatException('Invalid workspace tabs');
    final rows = value['tabs'] as List;
    if (rows.isEmpty || rows.length > 24)
      throw const FormatException('Invalid tab count');
    final tabs = <WorkspaceTab>[];
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          !RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(row['id']) ||
          !ids.add(row['id']) ||
          !routes.contains(row['route']) ||
          row['pinned'] is! bool ||
          row['group'] is! String ||
          (row['group'] as String).length > 48 ||
          RegExp(r'[\x00-\x1f]').hasMatch(row['group']))
        throw const FormatException('Invalid tab metadata');
      tabs.add(
        WorkspaceTab(
          id: row['id'],
          route: row['route'],
          pinned: row['pinned'],
          group: row['group'],
        ),
      );
    }
    if (!ids.contains(value['active']) ||
        !{'left', 'right', 'top', 'bottom'}.contains(value['dock']))
      throw const FormatException('Invalid active tab or dock');
    return WorkspaceTabs(
      tabs: tabs,
      active: value['active'],
      dock: value['dock'],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'tabs': tabs.map((t) => t.toJson()).toList(),
    'active': active,
    'dock': dock,
  };
}
