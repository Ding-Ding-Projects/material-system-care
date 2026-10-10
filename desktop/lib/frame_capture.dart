import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Explicit opt-in export of an actual painted application frame. This is not
/// a native-window screenshot and does not establish input or compositor proof.
class FrameCapture extends StatefulWidget {
  const FrameCapture({super.key, required this.output, required this.child});
  final String output;
  final Widget child;
  @override
  State<FrameCapture> createState() => _FrameCaptureState();
}

class _FrameCaptureState extends State<FrameCapture> {
  final boundary = GlobalKey();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => capture());
  }

  Future<void> capture() async {
    try {
      // Allow the initial Material route to settle, then capture a painted frame.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final file = File(widget.output);
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
        // Exclusive creation prevents overwriting an existing capture.
        await file.create(exclusive: true);
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      } finally {
        image.dispose();
      }
    } catch (_) {
      // No paths or private data are logged. A missing output is an export
      // failure, never a successful verification receipt.
    }
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: boundary, child: widget.child);
}
