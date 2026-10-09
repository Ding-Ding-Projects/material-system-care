import 'dart:async';
import 'wording_cache.dart';
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
    'textScale': 1.0,
    'notificationsInfo': true,
    'notificationsSuccess': true,
    'notificationsProgress': true,
  };
  Map<String, String> _vocabulary = {};
  String _vocabularyState = 'empty';
  bool _loading = true;
  bool _loaded = false;
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
        _loaded = true;
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
    if (!_loaded || _loading) return;
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

  Future<void> _loadVocabulary() async {
    try {
      final file = _vocabularyCache;
      if (!await file.exists()) return;
      if (await file.length() > 1048576)
        throw const FormatException('File exceeds limit');
      final loaded = WordingCache.validate(await file.readAsString());
      if (mounted)
        setState(() {
          _vocabulary = loaded;
          _vocabularyState = 'loaded';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _vocabulary = {};
          _vocabularyState = 'invalid';
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
        _vocabularyState = 'empty';
      });
      widget.onChanged({..._values, 'privateVocabulary': <String, String>{}});
    } catch (_) {
      if (mounted)
        setState(() {
          _error = _label(
            'The private cache could not be cleared. Retry.',
            '未能清除私人快取，請重試。',
          );
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
      final validated = await WordingCache(_vocabularyCache).replace(text);
      if (!mounted) return;
      setState(() {
        _vocabulary = validated;
        _vocabularyState = 'loaded';
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

  Widget _colorEditor() {
    final color =
        ((_values['seedColor'] as num?)?.toInt() ?? 0xff6750a4) & 0xffffffff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        TextFormField(
          key: ValueKey('color-$color'),
          initialValue: color.toRadixString(16).padLeft(8, '0').toUpperCase(),
          maxLength: 8,
          decoration: InputDecoration(
            labelText: _label('ARGB hexadecimal color', 'ARGB 十六進位顏色'),
            helperText: _label(
              'Eight hexadecimal digits: alpha, red, green, blue.',
              '八位十六進位數字：透明度、紅、綠、藍。',
            ),
            border: const OutlineInputBorder(),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) => RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(v ?? '')
              ? null
              : _label(
                  'Enter exactly eight hexadecimal digits.',
                  '請輸入八位十六進位數字。',
                ),
          onFieldSubmitted: (v) {
            if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(v))
              _change('seedColor', int.parse(v, radix: 16));
          },
        ),
        for (final channel in [
          (24, 'Alpha', '透明度'),
          (16, 'Red', '紅色'),
          (8, 'Green', '綠色'),
          (0, 'Blue', '藍色'),
        ])
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_label(channel.$2, channel.$3)}: ${(color >> channel.$1) & 255}',
              ),
              Slider(
                value: ((color >> channel.$1) & 255).toDouble(),
                min: 0,
                max: 255,
                divisions: 255,
                semanticFormatterCallback: (v) =>
                    '${_label(channel.$2, channel.$3)} ${v.round()}',
                onChanged: (v) => setState(() {
                  _values = {
                    ..._values,
                    'seedColor':
                        (color & ~(255 << channel.$1)) |
                        (v.round() << channel.$1),
                  };
                }),
                onChangeEnd: (v) => _change(
                  'seedColor',
                  (color & ~(255 << channel.$1)) | (v.round() << channel.$1),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _textScaleControl() {
    final scale = ((_values['textScale'] as num?)?.toDouble() ?? 1).clamp(
      0.8,
      2.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_label('Text scale', '文字比例')}: ${(scale * 100).round()}%'),
        Slider(
          value: scale,
          min: 0.8,
          max: 2,
          divisions: 24,
          label: '${(scale * 100).round()}%',
          onChanged: (v) => setState(() {
            _values = {..._values, 'textScale': v};
          }),
          onChangeEnd: (v) => _change('textScale', v),
        ),
        TextButton(
          onPressed: () => _change('textScale', 1.0),
          child: Text(_label('Reset text scale', '重設文字比例')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations:
            _values['reducedMotion'] == true ||
            MediaQuery.of(context).disableAnimations,
      ),
      child: ListView(
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
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
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
                      onPressed: _loading
                          ? null
                          : !_loaded
                          ? _load
                          : () => _change('theme', _values['theme']),
                      child: Text(
                        !_loaded
                            ? _label('Retry loading', '重試讀取')
                            : _label('Retry saving', '重試儲存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_saving)
            LinearProgressIndicator(
              semanticsLabel: _label('Saving settings', '正在儲存設定'),
            ),
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
                          0xff6750a4: _label('Purple', '紫色'),
                          0xff006a6a: _label('Teal', '青綠色'),
                          0xff00639b: _label('Blue', '藍色'),
                          0xff8b5000: _label('Amber', '琥珀色'),
                          0xff904a49: _label('Rose', '玫瑰色'),
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
              _colorEditor(),
              _textScaleControl(),
            ]),
          if (_matches(
            'language English Cantonese bilingual funny emoji 語言 英文 廣東話 雙語',
          ))
            _section('Language and messages', '語言及訊息', [
              _select('language', 'Language', '語言', {
                'en': _label('English', '英文'),
                'yue': _label('Cantonese', '廣東話'),
                'both': _label('Bilingual', '雙語'),
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
              Text(switch (_vocabularyState) {
                'loaded' => _label(
                  'Personal vocabulary loaded locally',
                  '已於本機載入個人用詞',
                ),
                'invalid' => _label(
                  'Saved personal vocabulary is invalid; original wording is active',
                  '已儲存的個人用詞無效，現正使用原有用詞',
                ),
                _ => _label('No personal vocabulary loaded', '尚未載入個人用詞'),
              }),
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
          if (_matches(
            'notifications information success progress warnings 通知 資訊 成功 進度 警告',
          ))
            _section('Notifications', '通知', [
              _toggle(
                'notificationsInfo',
                'Information notifications',
                '資訊通知',
                _label(
                  'Show non-blocking informational messages.',
                  '顯示不阻擋操作的資訊訊息。',
                ),
              ),
              _toggle(
                'notificationsSuccess',
                'Success notifications',
                '成功通知',
                _label('Show completed operation messages.', '顯示操作完成訊息。'),
              ),
              _toggle(
                'notificationsProgress',
                'Progress notifications',
                '進度通知',
                _label('Show measured operation progress.', '顯示實際量度的操作進度。'),
              ),
              Text(
                _label(
                  'Errors and warnings remain visible until dismissed. These preferences never hide safety decisions.',
                  '錯誤及警告會保留至關閉為止，以上偏好不會隱藏安全決定。',
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
                  'Stored preference only. Native speech playback is unavailable in this build.',
                  '只儲存偏好，此版本未提供原生朗讀功能。',
                ),
              ),
              _toggle(
                'sound',
                'Action sound preference',
                '操作音效偏好',
                _label(
                  'Off by default. Native sound playback is unavailable in this build.',
                  '預設關閉，此版本未提供原生音效播放。',
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
      ),
    );
  }
}
