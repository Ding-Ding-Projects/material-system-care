import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/frame_capture.dart';

void main() {
  test('PNG byte views exclude unrelated backing-buffer bytes', () {
    final backing = Uint8List.fromList([91, 92, 1, 2, 3, 93]);
    final data = ByteData.view(backing.buffer, 2, 3);
    expect(captureByteView(data), [1, 2, 3]);
  });

  test('frame paths and requests retain sequence identity', () {
    final start = DateTime.utc(2026, 10, 10, 12, 13, 14, 15, 16);
    final frame = CapturedPng(
      Uint8List.fromList([1, 2]),
      start,
      start.add(const Duration(microseconds: 20)),
      20,
      12,
      10,
    );
    expect(captureUtc(start), '2026-10-10T12:13:14.015016Z');
    for (final sequence in [0, 1, 19]) {
      final path = frameCapturePath('C:/test/frame.png', sequence);
      final request = frame.request(path, sequence);
      expect(request['sequence'], sequence);
      expect(request['width'], 12);
      expect(request['height'], 10);
      expect(request['pixelRatio'], 1.0);
      expect(
        request['path'],
        sequence == 0
            ? 'C:/test/frame.png'
            : 'C:/test/frame-${sequence.toString().padLeft(3, '0')}.png',
      );
    }
    expect(
      () => frameCapturePath('C:/test/frame.png', 20),
      throwsArgumentError,
    );
  });

  testWidgets('real repaint capture records UTC bounds and image dimensions', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 12,
            height: 10,
            child: RepaintBoundary(
              key: key,
              child: const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final started = DateTime.utc(2026, 10, 10, 12);
    int reads = 0;
    final frame = await tester.runAsync(
      () => capturePngFrame(
        boundary,
        clock: () => started.add(Duration(microseconds: reads++ * 20)),
      ),
    );
    expect(reads, 2);
    expect(frame!.started, started);
    expect(frame.completed, started.add(const Duration(microseconds: 20)));
    expect(frame.elapsedMicroseconds, greaterThanOrEqualTo(0));
    final png = ByteData.sublistView(frame.bytes);
    expect(png.getUint32(16), frame.width);
    expect(png.getUint32(20), frame.height);
    expect(frame.width, 12);
    expect(frame.height, 10);
    reads = 0;
    await tester.runAsync(() async {
      await expectLater(
        capturePngFrame(
          boundary,
          clock: () => started.subtract(Duration(seconds: reads++)),
        ),
        throwsStateError,
      );
    });
  });

  testWidgets(
    'disposing a pending capture cancels its timer and write request',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('material_system_care/engine');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        const FrameCapture(
          output: 'C:/unused/frame.png',
          child: SizedBox(width: 12, height: 10),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(calls, isEmpty);
    },
  );
}
