import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Counts only errors delivered to these hooks during explicit frame capture.
/// Original handlers retain their behavior; no messages or stacks are retained.
class CaptureDiagnostics {
  CaptureDiagnostics({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const limit = 1000;
  final DateTime Function() _clock;
  FlutterExceptionHandler? _previousFramework;
  bool Function(Object, StackTrace)? _previousPlatform;
  late final FlutterExceptionHandler _framework;
  late final bool Function(Object, StackTrace) _platform;
  DateTime? _started;
  int _frameworkCount = 0, _platformCount = 0, _dropped = 0;
  bool _active = false;

  void install() {
    if (_active || _started != null) {
      throw StateError('Capture diagnostic hooks may only be installed once.');
    }
    _previousFramework = FlutterError.onError;
    _previousPlatform = ui.PlatformDispatcher.instance.onError;
    _framework = (details) {
      _record(true);
      _previousFramework?.call(details);
    };
    _platform = (error, stack) {
      _record(false);
      return _previousPlatform?.call(error, stack) ?? false;
    };
    _started = _clock().toUtc();
    FlutterError.onError = _framework;
    ui.PlatformDispatcher.instance.onError = _platform;
    _active = true;
  }

  void _record(bool framework) {
    if (!_active) return;
    if (_frameworkCount + _platformCount >= limit) {
      if (_dropped < limit) _dropped++;
    } else if (framework) {
      _frameworkCount++;
    } else {
      _platformCount++;
    }
  }

  Map<String, Object> snapshot(int sequence, DateTime completed) {
    final started = _started;
    if (started == null ||
        sequence < 0 ||
        sequence >= 20 ||
        completed.toUtc().isBefore(started)) {
      throw StateError('Capture diagnostic interval is invalid.');
    }
    return {
      'schemaVersion': 1,
      'coverage': 'flutter-framework,platform-dispatcher',
      'startedUtc': _stamp(started),
      'completedUtc': _stamp(completed),
      'sequence': sequence,
      'frameworkErrorCount': _frameworkCount,
      'platformErrorCount': _platformCount,
      'droppedCount': _dropped,
      'healthy':
          _active &&
          _dropped == 0 &&
          identical(FlutterError.onError, _framework) &&
          identical(ui.PlatformDispatcher.instance.onError, _platform),
    };
  }

  String _stamp(DateTime time) {
    final text = time.toUtc().toIso8601String();
    final dot = text.indexOf('.');
    return '${text.substring(0, dot)}.${text.substring(dot + 1, text.length - 1).padRight(6, '0')}Z';
  }

  void dispose() {
    if (!_active) return;
    if (identical(FlutterError.onError, _framework)) {
      FlutterError.onError = _previousFramework;
    }
    if (identical(ui.PlatformDispatcher.instance.onError, _platform)) {
      ui.PlatformDispatcher.instance.onError = _previousPlatform;
    }
    _active = false;
  }
}
