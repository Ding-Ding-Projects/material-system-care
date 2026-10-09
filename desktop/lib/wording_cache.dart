import 'dart:convert';
import 'dart:io';

class WordingCache {
  WordingCache(this.file, {this.beforeReplace, this.writeTemporary});
  final File file;
  final Future<void> Function()? beforeReplace;
  final Future<void> Function(File, String)? writeTemporary;
  static WordingCache local() {
    final root = Platform.environment['LOCALAPPDATA'];
    if (root == null || root.isEmpty)
      throw const FileSystemException('Local application data unavailable');
    return WordingCache(
      File(
        '$root${Platform.pathSeparator}MaterialSystemCare${Platform.pathSeparator}private${Platform.pathSeparator}vocabulary.json',
      ),
    );
  }

  Future<Map<String, String>> load() async {
    if (!await file.exists()) return {};
    if (await file.length() > 1048576)
      throw const FormatException('File exceeds limit');
    return validate(await file.readAsString());
  }

  Future<Map<String, String>> replace(String text) async {
    final validated = validate(text);
    await file.parent.create(recursive: true);
    final temporary = File(
      '${file.path}.${pid}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      if (writeTemporary != null) {
        await writeTemporary!(temporary, text);
      } else {
        await temporary.writeAsString(text, flush: true);
      }
      // A same-directory rename commits a complete validated file. Never remove
      // the destination first, so a failed write/rename keeps the prior bytes.
      await beforeReplace?.call();
      await temporary.rename(file.path);
      return validated;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static void _checkJsonStructure(String text) {
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

  static Map<String, String> validate(String text) {
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
}
