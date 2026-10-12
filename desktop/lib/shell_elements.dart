import 'package:flutter/material.dart';

/// A concrete product element, bound by RegisteredElement to a rendered widget.
class ElementSpec {
  const ElementSpec(
    this.id,
    this.component,
    this.help,
    this.states, {
    this.action,
    this.motion = 'Material state layer',
  });
  final String id, component, help, motion;
  final String? action;
  final Set<String> states;
}

const shellElements = <String, ElementSpec>{
  'shell.chrome.surface': ElementSpec(
    'shell.chrome.surface',
    'Material surface with native caption gestures',
    'shell.window.help',
    {'active', 'inactive', 'restored', 'maximized'},
    action: 'window.drag',
    motion: 'Native window movement',
  ),
  'shell.chrome.title': ElementSpec(
    'shell.chrome.title',
    'Material title typography',
    'shell.window.help',
    {'ready'},
  ),
  'shell.chrome.minimize': ElementSpec(
    'shell.chrome.minimize',
    'IconButton',
    'shell.window.help',
    {'enabled', 'hover', 'focus', 'pressed'},
    action: 'window.minimize',
  ),
  'shell.chrome.maximize': ElementSpec(
    'shell.chrome.maximize',
    'IconButton',
    'shell.window.help',
    {'restored', 'maximized', 'hover', 'focus', 'pressed'},
    action: 'window.toggle-maximize',
  ),
  'shell.chrome.close': ElementSpec(
    'shell.chrome.close',
    'IconButton and review AlertDialog',
    'shell.window.help',
    {'enabled', 'review', 'hover', 'focus', 'pressed'},
    action: 'window.close',
  ),
  'shell.launcher': ElementSpec(
    'shell.launcher',
    'MenuAnchor with MenuItemButton',
    'workspace.open',
    {'closed', 'open', 'focus'},
    action: 'workspace.open',
  ),
  'shell.tabs.strip': ElementSpec(
    'shell.tabs.strip',
    'Material ListTile tab composition',
    'tabs.manage',
    {'empty', 'ready', 'overflow', 'filtered'},
  ),
  'shell.tabs.item': ElementSpec(
    'shell.tabs.item',
    'ListTile with selected Material surface',
    'tabs.manage',
    {'active', 'inactive', 'pinned', 'grouped', 'hover', 'focus', 'pressed'},
    action: 'tabs.activate',
  ),
  'shell.tabs.search': ElementSpec(
    'shell.tabs.search',
    'TextField with clear IconButton',
    'tabs.search',
    {'empty', 'matching', 'no-results', 'focus'},
    action: 'tabs.search',
  ),
  'shell.tabs.context': ElementSpec(
    'shell.tabs.context',
    'PopupMenuButton and AlertDialog',
    'tabs.manage',
    {'open', 'closed', 'pinned', 'grouped'},
    action: 'tabs.context',
  ),
  'shell.help': ElementSpec(
    'shell.help',
    'IconButton with AlertDialog',
    'shell.window.help',
    {'open', 'closed', 'focus'},
    action: 'help.context',
  ),
  'shell.notifications': ElementSpec(
    'shell.notifications',
    'IconButton with Drawer',
    'notifications.open',
    {'open', 'closed', 'focus'},
    action: 'notifications.open',
  ),
  'shell.content': ElementSpec(
    'shell.content',
    'IndexedStack with Offstage retained Material workspace',
    'workspace.open',
    {'ready', 'retained', 'unavailable'},
    motion: 'No state destruction on navigation',
  ),
};

class RegisteredElement extends StatelessWidget {
  const RegisteredElement({super.key, required this.id, required this.child});
  final String id;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final spec = shellElements[id];
    if (spec == null) throw StateError('Unknown rendered element: $id');
    return KeyedSubtree(key: ValueKey(spec.id), child: child);
  }
}
