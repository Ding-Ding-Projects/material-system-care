import 'package:material_system_care/diagnostic_response.dart';

Map<String, dynamic> stopCodeFixture() => {
  'hex': '0x0000009F',
  'decimal': 159,
  'name': 'DRIVER_POWER_STATE_FAILURE',
  'category': 'driver-power',
  'confidence':
      'The recorded code is evidence of the reported stop condition. It does not establish the root cause or identify a culprit driver.',
  'nextChecks': ['Preserve available dump files before making changes.'],
  'reference': diagnosticReference,
};

Map<String, dynamic> crashReportFixture() => {
  'collectedAt': '2026-10-09T12:00:00.0000000+00:00',
  'lookbackDays': 30,
  'eventLimit': 50,
  'events': <dynamic>[],
  'eventsTruncated': false,
  'dumps': <dynamic>[],
  'warnings': <dynamic>[],
  'dumpContentsRead': false,
  'uploaded': false,
  'rootCauseEstablished': false,
  'timeMeaning':
      'Recorded event times can follow the crash or restart; dump modification times are file metadata, not crash timestamps.',
  'limitation': 'Event evidence and file metadata only.',
};
