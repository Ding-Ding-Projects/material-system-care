import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart' as care;
import 'package:material_system_care/crash_diagnostics.dart';
import 'diagnostic_fixtures.dart';

void main() {
  for (final reduced in [true, false]) {
    testWidgets(
      'repeated diagnostic PageDown reaches dump metadata without refocusing, reduced=$reduced',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(care.Engine.channel, (call) async {
          final response = crashReportFixture();
          response['lookbackDays'] = 7;
          response['events'] = List.generate(
            45,
            (i) => {
              'eventId': 41,
              'provider': 'Microsoft-Windows-Kernel-Power',
              'recordId': i + 1,
              'recordedAt': '2026-10-10T12:00:00Z',
              'evidenceKind': 'unexpected-restart',
              'stopCode': null,
            },
          );
          response['dumps'] = [
            {
              'name': 'final-dump.dmp',
              'bytes': 1024,
              'modifiedAt': '2026-10-10T12:00:00Z',
              'analysis': 'metadata-only',
            },
          ];
          return {'ok': true, 'result': response};
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(care.Engine.channel, null),
        );
        await tester.pumpWidget(
          care.CareApp(
            startDiagnostics: true,
            isolatedCapture: true,
            capturePreferences: {
              'language': 'both',
              'theme': 'dark',
              'reducedMotion': reduced,
            },
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('7 days').last);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Read crash evidence'));
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        for (
          var tab = 0;
          tab < 4 &&
              FocusManager.instance.primaryFocus?.debugLabel !=
                  'DropdownButton<int>';
          tab++
        ) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'DropdownButton<int>',
        );
        final scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CrashDiagnosticsPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final initial = scrollable.position.pixels;
        for (var i = 0; i < 12; i++) {
          final before = scrollable.position.pixels;
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          if (!reduced && i == 0) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            expect(scrollable.position.pixels, greaterThan(before));
            expect(
              scrollable.position.pixels,
              lessThan(before + scrollable.position.viewportDimension * 0.8),
            );
          }
          await tester.pumpAndSettle();
          expect(
            FocusManager.instance.primaryFocus?.debugLabel,
            'Diagnostic paging',
          );
          expect(
            scrollable.position.pixels,
            greaterThan(before),
            reason: 'PageDown $i lost scroll focus',
          );
          if (find.text('final-dump.dmp').hitTestable().evaluate().isNotEmpty)
            break;
        }
        expect(scrollable.position.pixels, greaterThan(initial));
        expect(find.text('final-dump.dmp').hitTestable(), findsOneWidget);
        final bottom = scrollable.position.pixels;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, lessThan(bottom));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets('diagnostic paging leaves stop-code editing keys alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CrashDiagnosticsPage(
          invoke: (_, _) async => crashReportFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0x9F');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '0x9F');
    final focus = FocusManager.instance.primaryFocus;
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrollable.position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(focus));
    expect(scrollable.position.pixels, before);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '0x9F',
    );
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
