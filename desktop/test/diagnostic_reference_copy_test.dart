import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/crash_diagnostics.dart';
import 'package:material_system_care/diagnostic_response.dart';
import 'diagnostic_fixtures.dart';

const failure =
    'Reference copying did not complete. Select the visible reference to copy it manually.';

void main() {
  Future<void> showReference(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CrashDiagnosticsPage(invoke: (_, __) async => stopCodeFixture()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0x9f');
    await tester.tap(find.text('Explain stop code'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Copy Microsoft reference'));
  }

  for (final rejects in [false, true]) {
    testWidgets(
      'reference copy reports ${rejects ? 'rejected' : 'successful'} write without losing result',
      (tester) async {
        var writes = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                writes++;
                expect(call.arguments, {'text': diagnosticReference});
                if (rejects)
                  throw PlatformException(
                    code: 'write-rejected',
                    message: 'synthetic private detail',
                  );
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await showReference(tester);
        await tester.tap(find.text('Copy Microsoft reference'));
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(
          find.text(rejects ? failure : 'Microsoft reference copied.'),
          findsOneWidget,
        );
        expect(
          find.text(rejects ? 'Microsoft reference copied.' : failure),
          findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is SelectableText && w.data == diagnosticReference,
          ),
          findsOneWidget,
        );
        expect(find.textContaining('synthetic private detail'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disposed reference copy safely absorbs a pending rejected write',
    (tester) async {
      final pending = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') return pending.future;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await showReference(tester);
      await tester.tap(find.text('Copy Microsoft reference'));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.completeError(PlatformException(code: 'write-rejected'));
      await tester.pumpAndSettle();
      expect(find.text(failure), findsNothing);
      expect(find.text('Microsoft reference copied.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
