/// Bounded display-only overrides for an explicitly isolated capture run.
/// These values never represent physical display DPI or injected records.
Map<String, dynamic>? parseCapturePreferences(List<String> arguments) {
  for (final argument in arguments.where((a) => a.startsWith('--capture-'))) {
    if (argument == '--capture-on-input') continue;
    if (![
      'frame',
      'language',
      'theme',
      'text-scale',
      'motion',
    ].any((name) => argument.startsWith('--capture-$name=')))
      return null;
  }
  const options = {
    'language': {'en': 'en', 'yue': 'yue', 'both': 'both'},
    'theme': {'light': 'light', 'dark': 'dark'},
    'text-scale': {'1': 1.0, '1.25': 1.25, '1.5': 1.5, '2': 2.0},
    'motion': {'system': false, 'reduced': true},
  };
  const keys = {
    'language': 'language',
    'theme': 'theme',
    'text-scale': 'textScale',
    'motion': 'reducedMotion',
  };
  final result = <String, dynamic>{};
  for (final entry in options.entries) {
    final prefix = '--capture-${entry.key}';
    final matches = arguments.where((a) => a.startsWith(prefix)).toList();
    if (matches.isEmpty) continue;
    if (matches.length != 1 || !matches.single.startsWith('$prefix='))
      return null;
    final value = matches.single.substring(prefix.length + 1);
    if (!entry.value.containsKey(value)) return null;
    result[keys[entry.key]!] = entry.value[value];
  }
  return Map.unmodifiable(result);
}
