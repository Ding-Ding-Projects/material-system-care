import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/diagnostic_response.dart';
import 'diagnostic_fixtures.dart';

void main() {
  test('accepts complete bounded evidence and drops unrelated fields', () {
    final report = crashReportFixture()..['privateExtra'] = 'not retained';
    report['events'] = [
      {
        'eventId': 41,
        'provider': 'Microsoft-Windows-Kernel-Power',
        'recordId': 12,
        'recordedAt': null,
        'evidenceKind': 'stop-code-recorded',
        'stopCode': stopCodeFixture(),
      },
    ];
    report['dumps'] = [
      {
        'name': 'example.dmp',
        'bytes': 10,
        'modifiedAt': '2026-10-09T11:00:00Z',
        'analysis': 'metadata-only',
      },
    ];
    final parsed = validateCrashReport(report, 30);
    expect(parsed.containsKey('privateExtra'), false);
    expect(parsed['events'].single['stopCode']['decimal'], 159);
    expect(parsed['dumps'].single['bytes'], 10);
  });
  test('rejects malformed reports as a whole', () {
    final changes = <String, dynamic>{
      'events': 'invalid',
      'dumps': [42],
      'warnings': [null],
      'collectedAt': '2026-02-30T12:00:00Z',
      'lookbackDays': 7,
      'eventLimit': 50.0,
      'eventsTruncated': null,
      'uploaded': true,
      'dumpContentsRead': true,
      'rootCauseEstablished': true,
    };
    for (final entry in changes.entries) {
      final report = crashReportFixture()..[entry.key] = entry.value;
      expect(
        () => validateCrashReport(report, 30),
        throwsFormatException,
        reason: entry.key,
      );
    }
    expect(
      () => validateCrashReport(
        crashReportFixture()..['events'] = List.filled(51, {}),
        30,
      ),
      throwsFormatException,
    );
    expect(
      () => validateCrashReport(
        crashReportFixture()
          ..['dumps'] = [
            {
              'name': '../private.dmp',
              'bytes': 0,
              'modifiedAt': '2026-10-09T11:00:00Z',
              'analysis': 'metadata-only',
            },
          ],
        30,
      ),
      throwsFormatException,
    );
  });
  test(
    'rejects contradictory codes, unsafe references and malformed guidance',
    () {
      for (final change in <String, dynamic>{
        'decimal': 160,
        'hex': '0x9F',
        'name': 'bad\nname',
        'category': 'invented',
        'nextChecks': [],
        'reference': 'https://example.com/',
        'confidence': 42,
      }.entries) {
        expect(
          () =>
              validateStopCode(stopCodeFixture()..[change.key] = change.value),
          throwsFormatException,
          reason: change.key,
        );
      }
    },
  );
  test(
    'rejects wrong provider, evidence kind and duplicate event identity',
    () {
      final event = {
        'eventId': 41,
        'provider': 'Microsoft-Windows-Kernel-Power',
        'recordId': 12,
        'recordedAt': null,
        'evidenceKind': 'unexpected-restart',
        'stopCode': null,
      };
      for (final item in [
        event..['provider'] = 'other',
        {
          ...event,
          'provider': 'Microsoft-Windows-Kernel-Power',
          'evidenceKind': 'stop-code-recorded',
        },
      ]) {
        expect(
          () => validateCrashReport(
            crashReportFixture()..['events'] = [item],
            30,
          ),
          throwsFormatException,
        );
      }
      event['provider'] = 'Microsoft-Windows-Kernel-Power';
      expect(
        () => validateCrashReport(
          crashReportFixture()..['events'] = [event, event],
          30,
        ),
        throwsFormatException,
      );
    },
  );
}
