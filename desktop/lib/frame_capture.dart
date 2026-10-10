import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Explicit opt-in export of an actual painted application frame. This is not
/// a native-window screenshot and does not establish input or compositor proof.
class FrameCapture extends StatefulWidget {
  const FrameCapture({
    super.key,
    required this.output,
    required this.child,
    this.onInput = false,
  });
  final String output;
  final Widget child;
  final bool onInput;
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
      final file = File(
        number == 0
            ? original.path
            : '${original.path.substring(0, original.path.length - 4)}-${number.toString().padLeft(3, '0')}.png',
      );
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
      final image = await rendered.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return;
        // The native bridge creates and writes through one exclusive handle.
        await const MethodChannel(
          'material_system_care/engine',
        ).invokeMethod<void>('writeCapture', {
          'path': file.path,
          'bytes': bytes.buffer.asUint8List(),
        });
      } finally {
        image.dispose();
      }
    } catch (_) {
      // No paths or private data are logged. A missing output is an export
      // failure, never a successful verification receipt.
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
