const diagnosticReference =
    'https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2';

Never _invalid() => throw const FormatException('Invalid diagnostic response');

Map<String, dynamic> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) _invalid();
  return Map<String, dynamic>.from(value);
}

String _text(Object? value, [int max = 2048]) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value))
    _invalid();
  return value;
}

int _integer(Object? value, int max) {
  if (value is! int || value < 0 || value > max) _invalid();
  return value;
}

String _utc(Object? value) {
  final text = _text(value, 40);
  if (!RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?(Z|\+00:00)$',
      ).hasMatch(text) ||
      DateTime.tryParse(text) == null ||
      DateTime.parse(text).toIso8601String().substring(0, 19) !=
          text.substring(0, 19))
    _invalid();
  return text;
}

List<T> _list<T>(Object? value, int max, T Function(Object?) parse) {
  if (value is! List || value.length > max) _invalid();
  return value.map(parse).toList(growable: false);
}

Map<String, dynamic> validateStopCode(Object? value) {
  final v = _map(value);
  final decimal = _integer(v['decimal'], 0xffffffff);
  final hex = _text(v['hex'], 10);
  if (hex != '0x${decimal.toRadixString(16).toUpperCase().padLeft(8, '0')}')
    _invalid();
  final category = _text(v['category'], 64);
  if (!{
    'memory-or-driver',
    'memory',
    'exception',
    'driver-power',
    'hardware-report',
    'watchdog',
    'critical-process',
    'unknown',
  }.contains(category))
    _invalid();
  if (v['reference'] != diagnosticReference) _invalid();
  final checks = _list(v['nextChecks'], 16, _text);
  if (checks.isEmpty) _invalid();
  return {
    'hex': hex,
    'decimal': decimal,
    'name': _text(v['name'], 128),
    'category': category,
    'confidence': _text(v['confidence']),
    'nextChecks': checks,
    'reference': diagnosticReference,
  };
}

Map<String, dynamic> validateCrashReport(Object? value, int requestedDays) {
  final v = _map(value);
  if (v['lookbackDays'] is! int ||
      v['eventLimit'] is! int ||
      v['lookbackDays'] != requestedDays ||
      v['eventLimit'] != 50 ||
      v['eventsTruncated'] is! bool ||
      v['dumpContentsRead'] != false ||
      v['uploaded'] != false ||
      v['rootCauseEstablished'] != false)
    _invalid();
  final records = <int>{};
  final events = _list(v['events'], 50, (raw) {
    final e = _map(raw);
    final id = e['eventId'];
    if (id is! int) _invalid();
    if (!(id == 1001 &&
            e['provider'] == 'Microsoft-Windows-WER-SystemErrorReporting') &&
        !(id == 41 && e['provider'] == 'Microsoft-Windows-Kernel-Power'))
      _invalid();
    final record = e['recordId'] == null
        ? null
        : _integer(e['recordId'], 0x7fffffffffffffff);
    if (record != null && !records.add(record)) _invalid();
    final code = e['stopCode'] == null ? null : validateStopCode(e['stopCode']);
    final kind = code != null
        ? 'stop-code-recorded'
        : id == 1001
        ? 'bugcheck-report-without-readable-code'
        : 'unexpected-restart';
    if (e['evidenceKind'] != kind) _invalid();
    return {
      'eventId': id,
      'provider': e['provider'],
      'recordId': record,
      'recordedAt': e['recordedAt'] == null ? null : _utc(e['recordedAt']),
      'evidenceKind': kind,
      'stopCode': code,
    };
  });
  final dumps = _list(v['dumps'], 100, (raw) {
    final d = _map(raw);
    final name = _text(d['name'], 255);
    if (name.contains('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        name == '.' ||
        name == '..' ||
        d['analysis'] != 'metadata-only')
      _invalid();
    return {
      'name': name,
      'bytes': _integer(d['bytes'], 0x7fffffffffffffff),
      'modifiedAt': _utc(d['modifiedAt']),
      'analysis': 'metadata-only',
    };
  });
  return {
    'collectedAt': _utc(v['collectedAt']),
    'lookbackDays': requestedDays,
    'eventLimit': 50,
    'eventsTruncated': v['eventsTruncated'],
    'events': events,
    'dumps': dumps,
    'warnings': _list(v['warnings'], 16, _text),
    'dumpContentsRead': false,
    'uploaded': false,
    'rootCauseEstablished': false,
    'timeMeaning': _text(v['timeMeaning']),
    'limitation': _text(v['limitation']),
  };
}
