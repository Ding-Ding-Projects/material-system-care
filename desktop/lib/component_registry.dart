import 'package:flutter/material.dart';

/// Explicit approved component inventory. Layout primitives are noninteractive
/// internals only; new product controls must be registered before use.
const materialComponents = <String>{
  'Scaffold',
  'AppBar',
  'NavigationRail',
  'SearchBar',
  'MenuAnchor',
  'MenuItemButton',
  'CheckboxMenuButton',
  'FilledButton',
  'OutlinedButton',
  'TextButton',
  'IconButton',
  'Tooltip',
  'PopupMenuButton',
  'TextField',
  'DropdownButtonFormField',
  'SegmentedButton',
  'Slider',
  'SwitchListTile',
  'CheckboxListTile',
  'AlertDialog',
  'ExpansionTile',
  'ListTile',
  'Card',
  'LinearProgressIndicator',
  'Text',
  'SelectableText',
  'Divider',
  'Material',
};

void requireMaterialComponents(Set<String> renderedControls) {
  final unknown = renderedControls.difference(materialComponents);
  if (unknown.isNotEmpty) {
    throw StateError('Unregistered product controls: ${unknown.join(', ')}');
  }
}

ThemeData registeredTheme(Color seed, Brightness brightness) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
);
