import 'package:flutter/material.dart';
import 'localization.dart';

/// State-bound transition, never an idle animation. Official Material control
/// state layers continue to own hover, focus, press and selection feedback.
class OperationMotion extends StatelessWidget {
  const OperationMotion({super.key, required this.state});
  final String state;
  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        CopyScope.of(context)['reducedMotion'] == true;
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      reverseDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 160),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: state == 'idle'
          ? const SizedBox.shrink(key: ValueKey('idle'))
          : ListTile(
              key: ValueKey(state),
              dense: true,
              subtitle: state == 'cancelled'
                  ? const UiText(
                      'The engine was asked to cancel and may still be finishing.',
                    )
                  : null,
              leading: Icon(
                state == 'working'
                    ? Icons.pending_outlined
                    : state == 'error'
                    ? Icons.error_outline
                    : state == 'cancelled'
                    ? Icons.stop_circle_outlined
                    : Icons.check_circle_outline,
              ),
              title: UiText(
                state == 'working'
                    ? 'Reading local records…'
                    : state == 'error'
                    ? 'Operation could not complete'
                    : state == 'cancelled'
                    ? 'Stopped waiting for scan.'
                    : 'Result received from local engine',
              ),
            ),
    );
  }
}
