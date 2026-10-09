import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.invoke,
    required this.onChanged,
  });
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
  invoke;
  final void Function(Map<String, dynamic>) onChanged;
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  Map<String, dynamic> _values = {
    'theme': 'system',
    'seedColor': 0xff6750a4,
    'density': 'comfortable',
    'language': 'en',
    'funnyEnglish': 5,
    'funnyCantonese': 5,
    'emoji': true,
    'narration': false,
    'sound': false,
    'reducedMotion': false,
  };
  Map<String, String> _vocabulary = {};
  String _vocabularyState = 'No personal vocabulary loaded';
  bool _loading = true;
  bool _saving = false;
  bool _picking = false;
  String? _error;
  String _query = '';
  String? _pattern;
  String? _searchError;
  final _search = TextEditingController();
  final _builder = MenuController();
  Future<void> _saveQueue = Future<void>.value();
  String _wording(String text) {
    if (_vocabulary.isEmpty) return text;
    final keys = _vocabulary.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final pattern = RegExp(keys.map(RegExp.escape).join('|'));
    return text.replaceAllMapped(pattern, (match) => _vocabulary[match[0]]!);
  }

  String _label(String en, String yue) => switch (_values['language']) {
    'yue' => _wording(yue),
    'both' => '${_wording(en)} / ${_wording(yue)}',
    _ => _wording(en),
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await widget.invoke('settings.get', {
        'key': 'workspacePreferences',
      });
      final data = response['value'] is Map
          ? response['value'] as Map
          : response['settings'] is Map
          ? response['settings'] as Map
          : response.containsKey('items')
          ? <String, dynamic>{}
          : response;
      if (!mounted) return;
      setState(() {
        _values = {..._values, ...Map<String, dynamic>.from(data)};
        _loading = false;
      });
      await _loadVocabulary();
      widget.onChanged({..._values, 'privateVocabulary': Map.of(_vocabulary)});
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = _label(
            'Settings could not be loaded. Retry to read saved values.',
            '未能讀取設定，請重試。',
          );
        });
    }
  }

  void _change(String key, dynamic value) {
    setState(() {
      _values = {..._values, key: value};
      _saving = true;
      _error = null;
    });
    final snapshot = Map<String, dynamic>.of(_values);
    widget.onChanged({...snapshot, 'privateVocabulary': Map.of(_vocabulary)});
    _saveQueue = _saveQueue.then((_) async {
      try {
        await widget.invoke('settings.save', {
          'key': 'workspacePreferences',
          'value': snapshot,
        });
        if (mounted)
          setState(() {
            _saving = false;
          });
      } catch (_) {
        if (mounted)
          setState(() {
            _saving = false;
            _error = _label(
              'Settings were not saved. Retry saving.',
              '設定未儲存，請重試。',
            );
          });
      }
    });
  }

  File get _vocabularyCache {
    final root = Platform.environment['LOCALAPPDATA'];
    if (root == null || root.isEmpty)
      throw const FileSystemException('Local application data unavailable');
    return File(
      '$root${Platform.pathSeparator}MaterialSystemCare${Platform.pathSeparator}private${Platform.pathSeparator}vocabulary.json',
    );
  }

  void _checkJsonStructure(String text) {
    final containers = <int>[];
    final objectKeys = <Set<String>?>[];
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code == 34) {
        final start = i;
        var escaped = false;
        for (i++; i < text.length; i++) {
          final next = text.codeUnitAt(i);
          if (escaped) {
            escaped = false;
          } else if (next == 92) {
            escaped = true;
          } else if (next == 34) {
            break;
          }
        }
        if (i >= text.length)
          throw const FormatException('Unterminated string');
        var nextIndex = i + 1;
        while (nextIndex < text.length &&
            [9, 10, 13, 32].contains(text.codeUnitAt(nextIndex))) {
          nextIndex++;
        }
        if (nextIndex < text.length && text.codeUnitAt(nextIndex) == 58) {
          if (objectKeys.isEmpty || objectKeys.last == null || i - start > 1540)
            throw const FormatException('Invalid object key');
          final key = jsonDecode(text.substring(start, i + 1));
          if (key is! String || !objectKeys.last!.add(key))
            throw const FormatException('Duplicate object key');
        }
      } else if (code == 123 || code == 91) {
        containers.add(code);
        objectKeys.add(code == 123 ? <String>{} : null);
        if (containers.length > 3)
          throw const FormatException('Nesting exceeds limit');
      } else if (code == 125 || code == 93) {
        if (containers.isEmpty || containers.last != (code == 125 ? 123 : 91))
          throw const FormatException('Unbalanced structure');
        containers.removeLast();
        objectKeys.removeLast();
      }
    }
    if (containers.isNotEmpty)
      throw const FormatException('Unbalanced structure');
  }

  Map<String, String> _validateVocabulary(String text) {
    if (utf8.encode(text).length > 1048576)
      throw const FormatException('File exceeds limit');
    _checkJsonStructure(text);
    final data = jsonDecode(text);
    if (data is! Map ||
        data.length != 2 ||
        data['schemaVersion'] != 1 ||
        data['entries'] is! Map)
      throw const FormatException('Unsupported schema');
    final entries = data['entries'] as Map;
    if (entries.length > 2048) throw const FormatException('Too many entries');
    final result = <String, String>{};
    for (final entry in entries.entries) {
      if (entry.key is! String || entry.value is! String)
        throw const FormatException('Invalid entry');
      final key = entry.key as String;
      final value = entry.value as String;
      if (key.isEmpty ||
          key.length > 256 ||
          value.isEmpty ||
          value.length > 1024 ||
          ['__proto__', 'constructor', 'prototype'].contains(key) ||
          RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]').hasMatch(key + value))
        throw const FormatException('Invalid replacement');
      result[key] = value;
    }
    return result;
  }

  Future<void> _loadVocabulary() async {
    try {
      final file = _vocabularyCache;
      if (!await file.exists()) return;
      if (await file.length() > 1048576)
        throw const FormatException('File exceeds limit');
      final loaded = _validateVocabulary(await file.readAsString());
      if (mounted)
        setState(() {
          _vocabulary = loaded;
          _vocabularyState = 'Personal vocabulary loaded locally';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _vocabulary = {};
          _vocabularyState =
              'Saved personal vocabulary is invalid; original wording is active';
        });
    }
  }

  Future<void> _clearVocabulary() async {
    try {
      final file = _vocabularyCache;
      if (await file.exists()) await file.delete();
      if (!mounted) return;
      setState(() {
        _vocabulary = {};
        _vocabularyState = 'No personal vocabulary loaded';
      });
      widget.onChanged({..._values, 'privateVocabulary': <String, String>{}});
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'The private cache could not be cleared. Retry.';
        });
    }
  }

  Future<void> _pickVocabulary() async {
    if (_picking) return;
    setState(() {
      _picking = true;
    });
    try {
      final selectedPath =
          await const MethodChannel(
            'material_system_care/engine',
          ).invokeMethod<String>('pickFile', {
            'extensions': ['json'],
          });
      if (selectedPath == null) return;
      final selected = File(selectedPath);
      if (await selected.length() > 1048576)
        throw const FormatException('File exceeds limit');
      final text = await selected.readAsString();
      final validated = _validateVocabulary(text);
      final file = _vocabularyCache;
      await file.parent.create(recursive: true);
      await file.writeAsString(text, flush: true);
      if (!mounted) return;
      setState(() {
        _vocabulary = validated;
        _vocabularyState = 'Personal vocabulary loaded locally';
        _error = null;
      });
      widget.onChanged({..._values, 'privateVocabulary': Map.of(_vocabulary)});
    } catch (_) {
      if (mounted)
        setState(() {
          _error = _label(
            'The file was not accepted. Current wording remains unchanged.',
            '檔案未被接納，保留目前用詞。',
          );
        });
    } finally {
      if (mounted)
        setState(() {
          _picking = false;
        });
    }
  }

  bool _matches(String value) {
    if (_pattern != null) {
      try {
        return RegExp(_pattern!, caseSensitive: false).hasMatch(value);
      } on FormatException {
        return false;
      }
    }
    return value.toLowerCase().contains(_query.toLowerCase());
  }

  Widget _section(String en, String yue, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_label(en, yue), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _select(
    String key,
    String en,
    String yue,
    Map<String, String> choices,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: choices.containsKey(_values[key])
          ? _values[key] as String
          : choices.keys.first,
      decoration: InputDecoration(
        labelText: _label(en, yue),
        border: const OutlineInputBorder(),
      ),
      items: choices.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (value) {
        if (value != null) _change(key, value);
      },
    ),
  );
  Widget _toggle(String key, String en, String yue, String detail) =>
      SwitchListTile(
        title: Text(_label(en, yue)),
        subtitle: Text(detail),
        value: _values[key] == true,
        onChanged: (value) => _change(key, value),
        contentPadding: EdgeInsets.zero,
      );
  Widget _funny(String key, String en, String yue) {
    final value = ((_values[key] as num?)?.toDouble() ?? 5).clamp(1.0, 5.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_label(en, yue)}: ${value.toInt()}'),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 4,
          label: '${value.toInt()}',
          onChanged: (v) => setState(() {
            _values = {..._values, key: v.round()};
          }),
          onChangeEnd: (v) => _change(key, v.round()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _label('Settings', '設定'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        MenuAnchor(
          controller: _builder,
          menuChildren: [
            MenuItemButton(
              onPressed: () {
                _search.text = '^${RegExp.escape(_query)}';
                setState(() {
                  _pattern = _search.text;
                });
              },
              child: Text(_label('Starts with current text', '以目前文字開始')),
            ),
            MenuItemButton(
              onPressed: () {
                _search.text = '${RegExp.escape(_query)}\$';
                setState(() {
                  _pattern = _search.text;
                });
              },
              child: Text(_label('Ends with current text', '以目前文字結束')),
            ),
            MenuItemButton(
              onPressed: () {
                _search.text = '^${RegExp.escape(_query)}\$';
                setState(() {
                  _pattern = _search.text;
                });
              },
              child: Text(_label('Exact text', '完全相同文字')),
            ),
            MenuItemButton(
              onPressed: () => setState(() {
                _pattern = null;
                _searchError = null;
              }),
              child: Text(_label('Use literal search', '使用純文字搜尋')),
            ),
          ],
          builder: (context, controller, child) => TextField(
            controller: _search,
            maxLength: 256,
            decoration: InputDecoration(
              labelText: _label('Search settings', '搜尋設定'),
              errorText: _searchError,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: _label('Regular expression builder', '正則表達式工具'),
                icon: const Icon(Icons.data_object),
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
            onChanged: (value) => setState(() {
              _query = value;
              _searchError = null;
              if (_pattern != null) {
                try {
                  RegExp(value);
                  _pattern = value;
                } on FormatException {
                  _searchError = _label('Invalid expression', '表達式無效');
                }
              }
            }),
          ),
        ),
        if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: () => _change('theme', _values['theme']),
                    child: Text(_label('Retry saving', '重試儲存')),
                  ),
                ],
              ),
            ),
          ),
        if (_saving)
          const LinearProgressIndicator(semanticsLabel: 'Saving settings'),
        if (_matches('appearance theme color density 外觀 主題 顏色 密度'))
          _section('Appearance', '外觀', [
            _select('theme', 'Theme', '主題', {
              'system': _label('System', '跟隨系統'),
              'light': _label('Light', '淺色'),
              'dark': _label('Dark', '深色'),
            }),
            _select('density', 'Density', '密度', {
              'comfortable': _label('Comfortable', '舒適'),
              'compact': _label('Compact', '緊湊'),
            }),
            Text(_label('Accent color', '主題顏色')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  {
                        0xff6750a4: 'Purple',
                        0xff006a6a: 'Teal',
                        0xff00639b: 'Blue',
                        0xff8b5000: 'Amber',
                        0xff904a49: 'Rose',
                      }.entries
                      .map(
                        (e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _values['seedColor'] == e.key,
                          onSelected: (_) => _change('seedColor', e.key),
                        ),
                      )
                      .toList(),
            ),
          ]),
        if (_matches(
          'language English Cantonese bilingual funny emoji 語言 英文 廣東話 雙語',
        ))
          _section('Language and messages', '語言及訊息', [
            _select('language', 'Language', '語言', {
              'en': 'English',
              'yue': '廣東話',
              'both': 'English / 廣東話',
            }),
            _funny('funnyEnglish', 'English playfulness', '英文趣味程度'),
            _funny('funnyCantonese', 'Cantonese playfulness', '廣東話趣味程度'),
            _toggle(
              'emoji',
              'Show emojis in dialogs',
              '對話框顯示表情符號',
              _label('Changes message decoration only.', '只改變訊息裝飾。'),
            ),
            FilledButton.tonalIcon(
              onPressed: _picking ? null : _pickVocabulary,
              icon: const Icon(Icons.file_open),
              label: Text(
                _label('Load personal vocabulary JSON', '載入個人用詞 JSON'),
              ),
            ),
            Text(_vocabularyState),
            TextButton(
              onPressed: _picking ? null : _clearVocabulary,
              child: Text(_label('Clear personal vocabulary', '清除個人用詞')),
            ),
            Text(
              _label(
                'Local only. Schema: schemaVersion 1, entries mapping original strings to replacements. Maximum 1 MiB and 2048 entries.',
                '只限本機。格式：schemaVersion 1，entries 將原文對應至替換文字，上限 1 MiB 及 2048 項。',
              ),
            ),
          ]),
        if (_matches('accessibility narration sound motion 無障礙 旁白 音效 動畫'))
          _section('Accessibility and feedback', '無障礙及回饋', [
            _toggle(
              'narration',
              'Narration preference',
              '旁白偏好',
              _label(
                'Stored preference. Speech playback requires an available native voice service.',
                '儲存偏好，朗讀需要可用的原生語音服務。',
              ),
            ),
            _toggle(
              'sound',
              'Action sound preference',
              '操作音效偏好',
              _label(
                'Off by default. Sound playback requires a supported output service.',
                '預設關閉，播放需要支援的音訊服務。',
              ),
            ),
            _toggle(
              'reducedMotion',
              'Reduce motion',
              '減少動畫',
              _label('Use minimal transitions.', '使用最少過場動畫。'),
            ),
          ]),
      ],
    );
  }
}
