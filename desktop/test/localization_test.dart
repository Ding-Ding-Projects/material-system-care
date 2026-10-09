import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/provenance.dart';
import 'package:material_system_care/notifications.dart';

void main() {
  test('recorded receipt required for update time', () {
    expect(buildUpdatedAt(null), 'provenance unavailable');
    expect(
      buildUpdatedAt({
        'buildReceipt': {'builtUtc': 'invalid'},
      }),
      'provenance unavailable',
    );
    expect(
      buildUpdatedAt({
        'buildReceipt': {'builtUtc': '2026-10-09T01:13:14Z'},
      }),
      contains(':14'),
    );
    expect(
      buildVersion({
        'manifest': {'version': '0.1.0'},
      }),
      '0.1.0',
    );
  });
  for (final mode in ['en', 'yue', 'both']) {
    testWidgets('owned copy renders $mode without changing identifiers', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CopyScope(
            preferences: {'language': mode},
            child: Builder(
              builder: (context) => Column(
                children: [
                  const UiText('Analyze folder'),
                  Text(localize(context, 'C:/Storage/report.json')),
                  const UiText('Operation completed'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(
          mode == 'en'
              ? 'Analyze folder'
              : mode == 'yue'
              ? '分析資料夾'
              : 'Analyze folder\n分析資料夾',
        ),
        findsOneWidget,
      );
      expect(find.text('C:/Storage/report.json'), findsOneWidget);
    });
  }
  test('notification history bounded without input payload', () {
    Notices.instance.value = [];
    for (var i = 0; i < 150; i++) {
      Notices.instance.add('success', 'system.snapshot');
    }
    expect(Notices.instance.value.length, 100);
    expect(Notices.instance.value.first.operation, 'system.snapshot');
  });
}
