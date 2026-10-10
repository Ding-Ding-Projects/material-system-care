import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'capture_diagnostics.dart';

String captureUtc(DateTime value) {
  final utc = value.toUtc();
  String digits(int number, int width) => number.toString().padLeft(width, '0');
  return '${digits(utc.year, 4)}-${digits(utc.month, 2)}-${digits(utc.day, 2)}T${digits(utc.hour, 2)}:${digits(utc.minute, 2)}:${digits(utc.second, 2)}.${digits(utc.millisecond, 3)}${digits(utc.microsecond, 3)}Z';
}

Uint8List captureByteView(ByteData bytes) =>
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);

String frameCapturePath(String original, int sequence) {
  if (sequence < 0 ||
      sequence >= 20 ||
      !original.toLowerCase().endsWith('.png'))
    throw ArgumentError('Invalid capture sequence or extension');
  return sequence == 0
      ? original
      : '${original.substring(0, original.length - 4)}-${sequence.toString().padLeft(3, '0')}.png';
}

class CapturedPng {
  const CapturedPng(
    this.bytes,
    this.started,
    this.completed,
    this.elapsedMicroseconds,
    this.width,
    this.height, [
    this.diagnostics,
  ]);
  final Uint8List bytes;
  final DateTime started, completed;
  final int elapsedMicroseconds, width, height;
  final Map<String, Object>? diagnostics;
  Map<String, Object> request(String path, int sequence) => {
    'path': path,
    'bytes': bytes,
    'captureStartedUtc': captureUtc(started),
    'captureCompletedUtc': captureUtc(completed),
    'captureElapsedMicroseconds': elapsedMicroseconds,
    'sequence': sequence,
    'width': width,
    'height': height,
    'pixelRatio': 1.0,
    if (diagnostics != null) 'diagnostics': diagnostics!,
  };
}

Future<CapturedPng> capturePngFrame(
  RenderRepaintBoundary boundary, {
  DateTime Function()? clock,
  CaptureDiagnostics? diagnostics,
  int sequence = 0,
}) async {
  final now = clock ?? DateTime.now;
  final started = now().toUtc();
  final elapsed = Stopwatch()..start();
  final image = await boundary.toImage(pixelRatio: 1);
  elapsed.stop();
  final completed = now().toUtc();
  try {
    if (completed.isBefore(started))
      throw StateError('Capture clock reversed; no receipt was requested.');
    final snapshot = diagnostics?.snapshot(sequence, completed);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PNG encoding did not complete.');
    return CapturedPng(
      captureByteView(data),
      started,
      completed,
      elapsed.elapsedMicroseconds,
      image.width,
      image.height,
      snapshot,
    );
  } finally {
    image.dispose();
  }
}

/// Explicit opt-in export of an actual painted application frame. This is not
/// a native-window screenshot and does not establish input or compositor proof.
class FrameCapture extends StatefulWidget {
  const FrameCapture({
    super.key,
    required this.output,
    required this.child,
    this.onInput = false,
    this.diagnostics,
  });
  final String output;
  final Widget child;
  final bool onInput;
  final CaptureDiagnostics? diagnostics;
  @override
  State<FrameCapture> createState() => _FrameCaptureState();
}

class _FrameCaptureState extends State<FrameCapture> {
  final boundary = GlobalKey();
  Timer? pending;
  int sequence = 0;
  bool writing = false;
  @override
  void initState() {
    super.initState();
    if (widget.onInput) HardwareKeyboard.instance.addHandler(keyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => schedule());
  }

  bool keyEvent(KeyEvent event) {
    if (event is KeyUpEvent) schedule();
    return false;
  }

  void schedule() {
    if (!mounted || sequence >= 20) return;
    pending?.cancel();
    pending = Timer(const Duration(milliseconds: 800), capture);
  }

  @override
  void dispose() {
    widget.diagnostics?.dispose();
    pending?.cancel();
    if (widget.onInput) HardwareKeyboard.instance.removeHandler(keyEvent);
    super.dispose();
  }

  Future<void> capture() async {
    if (writing || !mounted || sequence >= 20) return;
    writing = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final original = File(widget.output);
      if (!original.isAbsolute ||
          !original.path.toLowerCase().endsWith('.png') ||
          original.path.startsWith(r'\\'))
        return;
      final number = sequence++;
      final file = File(frameCapturePath(original.path, number));
      if (!file.isAbsolute ||
          !file.path.toLowerCase().endsWith('.png') ||
          file.path.startsWith(r'\\') ||
          await file.exists())
        return;
      final rendered = boundary.currentContext?.findRenderObject();
      if (rendered is! RenderRepaintBoundary ||
          !rendered.hasSize ||
          rendered.size.isEmpty)
        return;
      final frame = await capturePngFrame(
        rendered,
        diagnostics: widget.diagnostics,
        sequence: number,
      );
      if (!mounted) return;
      // The native bridge writes and flushes the PNG and its paired receipt.
      await const MethodChannel(
        'material_system_care/engine',
      ).invokeMethod<void>('writeCapture', frame.request(file.path, number));
    } catch (error) {
      // Report outcome without exposing paths or reflecting arbitrary errors.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            error is PlatformException &&
                    error.code == 'CAPTURE_RECEIPT_INCOMPLETE'
                ? 'PNG saved but capture receipt is incomplete.'
                : 'Frame capture did not produce a verified PNG and receipt.',
          ),
          library: 'frame_capture',
        ),
      );
    } finally {
      writing = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerUp: widget.onInput ? (_) => schedule() : null,
    child: RepaintBoundary(key: boundary, child: widget.child),
  );
}
