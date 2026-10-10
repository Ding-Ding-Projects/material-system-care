import 'dart:async';
import 'package:material_system_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/file_use.dart';
import 'package:material_system_care/localization.dart';

void main() {
  testWidgets('isolated entry reads no persisted settings or file records', (
    tester,
  ) async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(Engine.channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(Engine.channel, null));
    await tester.pumpWidget(
      const CareApp(startFileUse: true, isolatedCapture: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FileUsePage), findsOneWidget);
    expect(calls, isEmpty);
  });
  testWidgets('mismatched request identity cannot display file owners', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FileUsePage(
          invoke: (_, parameters) async => {
            'requestedPath': 'different',
            'path': parameters['path'],
            'owners': [],
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), r'C:\example.txt');
    await tester.pump();
    await tester.tap(find.text('Inspect file use'));
    await tester.pumpAndSettle();
    expect(find.text('Inspected file'), findsNothing);
    expect(
      find.text(
        'File-use inspection is unavailable. No process or handle was closed.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('explicit inspection sends one path and empty result is advisory', (
    tester,
  ) async {
    final calls = <(String, Map<String, dynamic>)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: FileUsePage(
          invoke: (method, parameters) async {
            calls.add((method, parameters));
            return {
              'requestedPath': parameters['path'],
              'path': parameters['path'],
              'owners': [],
            };
          },
        ),
      ),
    );
    expect(calls, isEmpty);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Inspect file use'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), r'C:\example.txt');
    await tester.pump();
    await tester.tap(find.text('Inspect file use'));
    await tester.pumpAndSettle();
    expect(calls.single.$1, 'files.lockOwners');
    expect(calls.single.$2, {'path': r'C:\example.txt'});
    expect(
      find.text(
        'No affected applications were reported. This does not prove that the file is unlocked.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), r'C:\another.txt');
    await tester.pump();
    expect(find.text('Inspected file'), findsNothing);
  });

  testWidgets(
    'refresh failure removes old records and hides raw exception details',
    (tester) async {
      var fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FileUsePage(
            invoke: (_, parameters) async {
              if (fail) throw StateError('LOCK_QUERY_BUSY: private detail');
              return {
                'requestedPath': parameters['path'],
                'path': parameters['path'],
                'owners': [
                  {
                    'processId': 42,
                    'name': 'Example owner',
                    'service': 'Example service',
                    'restartable': false,
                  },
                ],
              };
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), r'C:\example.txt');
      await tester.pump();
      await tester.tap(find.text('Inspect file use'));
      await tester.pumpAndSettle();
      expect(find.text('Example owner'), findsOneWidget);
      fail = true;
      await tester.tap(find.text('Inspect file use'));
      await tester.pumpAndSettle();
      expect(find.text('Example owner'), findsNothing);
      expect(
        find.text('File use changed during inspection. Try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('private detail'), findsNothing);
    },
  );

  testWidgets(
    'picker is explicit, cancel preserves path and wording follows scope',
    (tester) async {
      String? selection = r'C:\picked.txt';
      var engineCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CopyScope(
            preferences: const {'language': 'yue'},
            child: FileUsePage(
              pickFile: () async => selection,
              invoke: (_, __) async {
                engineCalls++;
                return {};
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('選擇檔案'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        selection,
      );
      selection = null;
      await tester.tap(find.text('選擇檔案'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        r'C:\picked.txt',
      );
      expect(engineCalls, 0);
    },
  );

  testWidgets('pending inspection disables edits and tolerates disposal', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(home: FileUsePage(invoke: (_, __) => pending.future)),
    );
    await tester.enterText(find.byType(TextField), r'C:\example.txt');
    await tester.pump();
    await tester.tap(find.text('Inspect file use'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete({'path': r'C:\example.txt', 'owners': []});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
