import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/provenance.dart';

void main() {
  test('selected receipt version wins over static manifest', () {
    expect(
      buildVersion({
        'buildReceipt': {'version': '0.8.1'},
        'manifest': {'version': '0.1.0'},
      }),
      '0.8.1',
    );
  });
  test('absent receipt version preserves manifest and null fallbacks', () {
    expect(
      buildVersion({
        'manifest': {'version': '0.1.0'},
      }),
      '0.1.0',
    );
    expect(
      buildVersion({
        'buildReceipt': {'version': null},
        'manifest': {'version': '0.1.0'},
      }),
      '0.1.0',
    );
    expect(buildVersion(null), 'build metadata unavailable');
    expect(buildVersion({'buildReceipt': null}), 'build metadata unavailable');
  });
  test(
    'invalid present receipt version does not conceal invalid provenance',
    () {
      expect(
        buildVersion({
          'buildReceipt': {'version': 'invalid'},
          'manifest': {'version': '0.1.0'},
        }),
        'build metadata unavailable',
      );
    },
  );
  testWidgets('factual selected version bypasses personal wording', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CopyScope(
          preferences: {
            'privateVocabulary': {'0.8.1': 'changed'},
          },
          child: BuildProvenance(
            ping: {
              'buildReceipt': {'version': '0.8.1'},
              'manifest': {'version': '0.1.0'},
            },
          ),
        ),
      ),
    );
    expect(find.text('Version: 0.8.1'), findsOneWidget);
    expect(find.textContaining('changed'), findsNothing);
  });
}
