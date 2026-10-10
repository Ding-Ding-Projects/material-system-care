import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/capture_diagnostics.dart';
import 'package:material_system_care/frame_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final time = DateTime.utc(2026, 10, 10, 12);
  late FlutterExceptionHandler? originalFramework;
  late bool Function(Object, StackTrace)? originalPlatform;
  setUp(() {
    originalFramework = FlutterError.onError;
    originalPlatform = ui.PlatformDispatcher.instance.onError;
  });
  tearDown(() {
    FlutterError.onError = originalFramework;
    ui.PlatformDispatcher.instance.onError = originalPlatform;
  });

  test(
    'registered hooks count injected errors and forward original handlers',
    () {
      var framework = 0, platform = 0;
      FlutterError.onError = (_) => framework++;
      ui.PlatformDispatcher.instance.onError = (_, _) {
        platform++;
        return true;
      };
      final beforeFramework = FlutterError.onError;
      final beforePlatform = ui.PlatformDispatcher.instance.onError;
      final diagnostics = CaptureDiagnostics(clock: () => time)..install();
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('private detail')),
      );
      expect(
        ui.PlatformDispatcher.instance.onError!(
          StateError('private detail'),
          StackTrace.current,
        ),
        isTrue,
      );
      final snapshot = diagnostics.snapshot(3, time);
      expect(snapshot['frameworkErrorCount'], 1);
      expect(snapshot['platformErrorCount'], 1);
      expect(snapshot['healthy'], isTrue);
      expect(snapshot.toString(), isNot(contains('private detail')));
      expect(framework, 1);
      expect(platform, 1);
      diagnostics.dispose();
      expect(FlutterError.onError, same(beforeFramework));
      expect(ui.PlatformDispatcher.instance.onError, same(beforePlatform));
    },
  );

  test('absent replaced and overflowed hooks cannot claim healthy zero', () {
    final absent = CaptureDiagnostics(clock: () => time);
    expect(() => absent.snapshot(0, time), throwsStateError);
    FlutterError.onError = (_) {};
    final diagnostics = CaptureDiagnostics(clock: () => time)..install();
    for (var i = 0; i < 1002; i++) {
      FlutterError.reportError(FlutterErrorDetails(exception: StateError('x')));
    }
    final snapshot = diagnostics.snapshot(0, time);
    expect(snapshot['frameworkErrorCount'], 1000);
    expect(snapshot['droppedCount'], 2);
    expect(snapshot['healthy'], isFalse);
    diagnostics.dispose();
    final replaced = CaptureDiagnostics(clock: () => time)..install();
    final replacement = (FlutterErrorDetails _) {};
    FlutterError.onError = replacement;
    expect(replaced.snapshot(0, time)['healthy'], isFalse);
    replaced.dispose();
    expect(FlutterError.onError, same(replacement));
  });

  test('invalid sequence and reversed diagnostic clock are rejected', () {
    final diagnostics = CaptureDiagnostics(clock: () => time)..install();
    addTearDown(diagnostics.dispose);
    expect(diagnostics.snapshot(63, time)['sequence'], 63);
    expect(() => diagnostics.snapshot(64, time), throwsStateError);
    expect(
      () => diagnostics.snapshot(0, time.subtract(const Duration(seconds: 1))),
      throwsStateError,
    );
  });

  testWidgets('real painted frame carries its observed diagnostic sequence', (
    tester,
  ) async {
    FlutterError.onError = (_) {};
    final diagnostics = CaptureDiagnostics(clock: () => time)..install();
    addTearDown(diagnostics.dispose);
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('injected')),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: key, child: const SizedBox(width: 12, height: 10)),
    );
    final frame = await tester.runAsync(
      () => capturePngFrame(
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary,
        clock: () => time,
        diagnostics: diagnostics,
        sequence: 2,
      ),
    );
    final request = frame!.request('C:/test/frame-002.png', 2);
    final snapshot = request['diagnostics']! as Map<String, Object>;
    expect(snapshot['sequence'], request['sequence']);
    expect(snapshot['completedUtc'], request['captureCompletedUtc']);
    expect(snapshot['frameworkErrorCount'], 1);
    expect(snapshot['healthy'], isTrue);
  });
}
