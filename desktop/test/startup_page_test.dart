import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/startup.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/localization.dart';

Map<String, dynamic> row({bool enabled = true, String revision = 'A'}) => {
  'id': 'Disposable entry',
  'name': 'Disposable entry',
  'enabled': enabled,
  'scope': 'user',
  'source': enabled ? 'HKCU.Run' : 'originalStateJournal',
  'reviewRevision': revision * 64,
  'canChange': true,
  'recoveryRequired': false,
  if (enabled) 'command': 'fixture command',
};

void main() {
  testWidgets('stale feedback remains bilingual after a rejected review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<Map<String, dynamic>> invoke(
      String method,
      Map<String, dynamic> params,
    ) async {
      if (method == 'startup.list')
        return {
          'records': [row()],
        };
      throw StateError('STARTUP_REVIEW_CHANGED');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: CopyScope(
          preferences: const {'language': 'both'},
          child: StartupPage(invoke: invoke),
        ),
      ),
    );
    await tester.tap(find.textContaining('Refresh records'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Review disable'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Confirm selected action'));
    await tester.pumpAndSettle();
    final feedback = tester.widget<Text>(
      find.textContaining('The startup record changed.'),
    );
    expect(feedback.data, contains('啟動記錄已變更'));
    expect(feedback.data, contains('請再次覆核所選操作'));
  });
  test('typed startup records reject contradictory metadata', () {
    expect(
      StartupRecord.parse({
        'records': [row()],
      }).single.canChange,
      isTrue,
    );
    for (final replacement in <String, dynamic>{
      'id': 'bad\nname',
      'enabled': 'true',
      'scope': 'machine',
      'source': 'originalStateJournal',
      'reviewRevision': 'missing',
      'canChange': 'true',
      'recoveryRequired': null,
      'command': 5,
    }.entries) {
      expect(
        () => StartupRecord.parse({
          'records': [
            {...row(), replacement.key: replacement.value},
          ],
        }),
        throwsFormatException,
        reason: replacement.key,
      );
    }
    expect(
      () => StartupRecord.parse({
        'records': [row(), row()],
      }),
      throwsFormatException,
    );
    expect(
      StartupRecord.parse({
        'records': [
          {...row(), 'recoveryRequired': true},
        ],
      }).single.canChange,
      isFalse,
    );
  });

  testWidgets(
    'cancelled review sends no mutation; confirmed review uses exact revision',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final writes = <Map<String, dynamic>>[];
      bool enabled = true;
      Future<Map<String, dynamic>> invoke(
        String method,
        Map<String, dynamic> params,
      ) async {
        if (method == 'startup.list')
          return {
            'records': [row(enabled: enabled)],
          };
        writes.add(params);
        enabled = params['enabled'] as bool;
        return {
          'completed': true,
          'id': params['id'],
          'enabled': enabled,
          'restartInitiated': false,
        };
      }

      await tester.pumpWidget(MaterialApp(home: StartupPage(invoke: invoke)));
      expect(writes, isEmpty);
      await tester.tap(find.text('Refresh records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review disable'));
      await tester.pumpAndSettle();
      expect(find.text('Disable selected startup entry'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(find.text('Review disable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm selected action'));
      await tester.pumpAndSettle();
      expect(writes, [
        {
          'id': 'Disposable entry',
          'enabled': false,
          'reviewRevision': 'A' * 64,
          'confirmed': true,
        },
      ]);
      expect(find.text('Review enable'), findsOneWidget);
      expect(
        find.text('Startup change completed and records refreshed.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('stale review refreshes without silently retrying', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int reads = 0;
    final revisions = <String>[];
    Future<Map<String, dynamic>> invoke(
      String method,
      Map<String, dynamic> params,
    ) async {
      if (method == 'startup.list')
        return {
          'records': [row(revision: ++reads == 1 ? 'A' : 'B')],
        };
      revisions.add(params['reviewRevision'] as String);
      throw StateError('STARTUP_REVIEW_CHANGED');
    }

    await tester.pumpWidget(MaterialApp(home: StartupPage(invoke: invoke)));
    await tester.tap(find.text('Refresh records'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review disable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm selected action'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(revisions, ['A' * 64]);
    expect(find.textContaining('The startup record changed.'), findsOneWidget);
    await tester.tap(find.text('Review disable'));
    await tester.pumpAndSettle();
    expect(revisions.length, 1);
    await tester.tap(find.text('Confirm selected action'));
    await tester.pumpAndSettle();
    expect(revisions, ['A' * 64, 'B' * 64]);
  });

  testWidgets(
    'invalid refreshed inventory removes earlier actionable records',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int reads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPage(
            invoke: (_, __) async => {
              'records': ++reads == 1 ? [row()] : ['invalid'],
            },
          ),
        ),
      );
      await tester.tap(find.text('Refresh records'));
      await tester.pumpAndSettle();
      expect(find.text('Review disable'), findsOneWidget);
      await tester.tap(find.text('Refresh records'));
      await tester.pumpAndSettle();
      expect(find.text('Review disable'), findsNothing);
      expect(find.textContaining('unavailable or invalid'), findsOneWidget);
    },
  );

  testWidgets('startup capture route excludes persisted personal settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CareApp(
        startStartup: true,
        isolatedCapture: true,
        capturePreferences: {
          'language': 'both',
          'theme': 'dark',
          'textScale': 2.0,
          'reducedMotion': true,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StartupPage), findsOneWidget);
    expect(find.textContaining('檢視登入啟動項目'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
