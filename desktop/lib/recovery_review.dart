import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cleanup.dart';
import 'localization.dart';

/// Confirmation of already validated receipt details, not current file availability.
class RecoveryReviewDialog extends StatefulWidget {
  const RecoveryReviewDialog({super.key, required this.files});
  final List<CleanupFile> files;
  @override
  State<RecoveryReviewDialog> createState() => _RecoveryReviewDialogState();
}

class _RecoveryReviewDialogState extends State<RecoveryReviewDialog> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'Recovery review paging');
  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _page(FocusNode node, KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !_scroll.hasClients ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null)
      return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.pageDown && key != LogicalKeyboardKey.pageUp)
      return KeyEventResult.ignored;
    final position = _scroll.position;
    final target =
        (position.pixels +
                position.viewportDimension *
                    (key == LogicalKeyboardKey.pageDown ? .8 : -.8))
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    _focus.requestFocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    autofocus: true,
    onKeyEvent: _page,
    child: AlertDialog(
      semanticLabel: localize(context, 'Review recovery files'),
      content: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: UiText(
                'Review recovery files',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),
            const UiText(
              'Review recorded files before restoration. Existing files will not be overwritten; availability is checked during restoration.',
            ),
            for (final file in widget.files) ...[
              const SizedBox(height: 12),
              SelectableText(file.path),
              Text(
                '${localize(context, 'Recorded state')}: ${localize(context, cleanupStateLabel(file.state))}',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const UiText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const UiText('Confirm selected action'),
        ),
      ],
    ),
  );
}
