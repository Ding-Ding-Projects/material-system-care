import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'localization.dart';

/// Keeps the official app bar while allowing localized titles to use their
/// complete requested text scale instead of overflowing a fixed toolbar.
AppBar inspectionAppBar(BuildContext context, String title) {
  final media = MediaQuery.of(context);
  final theme = Theme.of(context);
  final style = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!;
  final text = localize(context, title);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: media.textScaler,
  )..layout(maxWidth: math.max(1, media.size.width - 112));
  final height = math.max(kToolbarHeight, painter.height.ceilToDouble() + 16);
  painter.dispose();
  return AppBar(
    toolbarHeight: height,
    title: MediaQuery(
      data: media,
      child: Text(text, style: style, maxLines: 100, softWrap: true),
    ),
  );
}
