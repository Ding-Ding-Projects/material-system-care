import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inspection_app_bar.dart';
import 'labeled_controls.dart';
import 'localization.dart';
import 'motion.dart';
import 'notifications.dart';
import 'storage_analysis.dart'
    show normalizeAnalysisPath, StorageAnalysisInvoke;

class DuplicateGroup {
  const DuplicateGroup(
    this.size,
    this.totalMatchingFiles,
    this.reclaimableBytes,
    this.pathsTruncated,
    this.paths,
  );
  final int size, totalMatchingFiles, reclaimableBytes;
  final bool pathsTruncated;
  final List<String> paths;
}

class DuplicateAnalysis {
  const DuplicateAnalysis({
    required this.root,
    required this.groups,
    required this.hashedBytes,
    required this.changedOrUnavailable,
    required this.inaccessible,
    required this.reparseSkipped,
    required this.tooDeep,
    required this.budgetReached,
    required this.truncated,
  });
  final String root;
  final List<DuplicateGroup> groups;
  final int hashedBytes, changedOrUnavailable, inaccessible, reparseSkipped;
  final int tooDeep;
  final bool budgetReached, truncated;
  bool get incomplete =>
      tooDeep > 0 ||
      budgetReached ||
      truncated ||
      changedOrUnavailable > 0 ||
      inaccessible > 0 ||
      reparseSkipped > 0;
  int get potentialBytes =>
      groups.fold(0, (sum, group) => sum + group.reclaimableBytes);

  factory DuplicateAnalysis.parse(
    Map<String, dynamic> value,
    String requestedRoot,
  ) {
    const hashLimit = 512 * 1024 * 1024;
    int count(Object? value, int max) {
      if (value is! int || value < 0 || value > max)
        throw const FormatException('Invalid count');
      return value;
    }

    final root = normalizeAnalysisPath(requestedRoot);
    if (value['root'] is! String ||
        normalizeAnalysisPath(value['root'] as String).toLowerCase() !=
            root.toLowerCase() ||
        value['mutationPerformed'] != false ||
        value['budgetReached'] is! bool ||
        value['truncated'] is! bool) {
      throw const FormatException('Invalid duplicate scope');
    }
    final hashed = count(value['hashedBytes'], hashLimit);
    final rawGroups = value['groups'];
    if (rawGroups is! List || rawGroups.length > 100)
      throw const FormatException('Invalid groups');
    final prefix = (root.endsWith(r'\') ? root : '$root\\').toLowerCase();
    final seen = <String>{};
    final groups = <DuplicateGroup>[];
    var matched = 0;
    var matchedBytes = 0;
    for (final raw in rawGroups) {
      if (raw is! Map ||
          raw['verification'] != 'sha256-and-byte-comparison' ||
          raw['pathsTruncated'] is! bool) {
        throw const FormatException('Invalid verification');
      }
      final size = count(raw['size'], hashLimit);
      final total = count(raw['totalMatchingFiles'], 10000);
      final potential = count(raw['reclaimableBytes'], hashLimit);
      final paths = raw['paths'];
      if (total < 2 ||
          paths is! List ||
          paths.length < 2 ||
          paths.length > 20 ||
          paths.length != (total > 20 ? 20 : total) ||
          raw['pathsTruncated'] != (total > 20) ||
          potential != size * (total - 1))
        throw const FormatException('Invalid group totals');
      matched += total;
      if (matched > 10000 || size * total > hashed - matchedBytes)
        throw const FormatException('Invalid hashed total');
      matchedBytes += size * total;
      final parsedPaths = <String>[];
      for (final path in paths) {
        if (path is! String) throw const FormatException('Invalid path');
        final normalized = normalizeAnalysisPath(path);
        if (normalized.toLowerCase() == root.toLowerCase() ||
            !normalized.toLowerCase().startsWith(prefix) ||
            !seen.add(normalized.toLowerCase()))
          throw const FormatException('Invalid group path');
        parsedPaths.add(normalized);
      }
      groups.add(
        DuplicateGroup(
          size,
          total,
          potential,
          raw['pathsTruncated'] as bool,
          List.unmodifiable(parsedPaths),
        ),
      );
    }
    return DuplicateAnalysis(
      root: root,
      groups: List.unmodifiable(groups),
      hashedBytes: hashed,
      changedOrUnavailable: count(value['changedOrUnavailable'], 100000000),
      inaccessible: count(value['inaccessible'], 10001),
      reparseSkipped: count(value['reparseSkipped'], 10001),
      tooDeep: count(value['tooDeep'], 10001),
      budgetReached: value['budgetReached'] as bool,
      truncated: value['truncated'] as bool,
    );
  }
}

class DuplicateAnalysisPage extends StatefulWidget {
  const DuplicateAnalysisPage({
    super.key,
    required this.invoke,
    required this.cancel,
    this.pickFolder,
  });
  final StorageAnalysisInvoke invoke;
  final Future<bool> Function(String requestId) cancel;
  final Future<String?> Function()? pickFolder;
  @override
  State<DuplicateAnalysisPage> createState() => _DuplicateAnalysisPageState();
}

class _DuplicateAnalysisPageState extends State<DuplicateAnalysisPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final pagingFocus = FocusNode(debugLabel: 'Duplicate analysis paging');
  DuplicateAnalysis? result;
  String? message, requestId;
  bool busy = false,
      reviewing = false,
      cancelRequested = false,
      cancelled = false;
  int revision = 0, sequence = 0;

  @override
  void dispose() {
    final id = requestId;
    if (id != null && !cancelRequested)
      unawaited(widget.cancel(id).catchError((_) => false));
    input.dispose();
    scroll.dispose();
    pagingFocus.dispose();
    super.dispose();
  }

  KeyEventResult pageKey(FocusNode node, KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !scroll.hasClients ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.pageDown && key != LogicalKeyboardKey.pageUp)
      return KeyEventResult.ignored;
    final position = scroll.position;
    final target =
        (position.pixels +
                position.viewportDimension *
                    (key == LogicalKeyboardKey.pageDown ? .8 : -.8))
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    pagingFocus.requestFocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      scroll.jumpTo(target);
    } else {
      scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
    return KeyEventResult.handled;
  }

  void changed() {
    revision++;
    setState(() {
      result = null;
      message = null;
      cancelled = false;
    });
  }

  Future<void> choose() async {
    if (busy || reviewing) return;
    final selectedRevision = revision;
    try {
      final selected =
          await (widget.pickFolder?.call() ??
              const MethodChannel(
                'material_system_care/engine',
              ).invokeMethod<String>('pickDirectory'));
      if (!mounted || selected == null || selectedRevision != revision) return;
      input.text = selected;
      changed();
    } catch (_) {
      if (mounted && selectedRevision == revision) {
        setState(() {
          result = null;
          message =
              'The folder picker is unavailable. Enter a full folder path.';
        });
      }
    }
  }

  Future<void> cancelRead() async {
    final id = requestId;
    if (id == null || cancelRequested) return;
    setState(() {
      cancelRequested = true;
      message =
          'Cancellation requested. Waiting for the current read to settle.';
    });
    try {
      final accepted = await widget.cancel(id);
      if (mounted && requestId == id && !accepted)
        setState(
          () => message =
              'Cancellation could not be requested. The current read may still complete.',
        );
    } catch (_) {
      if (mounted && requestId == id)
        setState(
          () => message =
              'Cancellation could not be requested. The current read may still complete.',
        );
    }
  }

  Future<void> analyze() async {
    if (busy || reviewing) return;
    late final String root;
    try {
      root = normalizeAnalysisPath(input.text.trim());
    } catch (_) {
      setState(() {
        result = null;
        message = 'Enter a full absolute folder path.';
      });
      return;
    }
    final selectedRevision = revision;
    setState(() => reviewing = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const UiText('Review duplicate analysis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiText(
                'Only this folder will be read. No files will be moved, changed or deleted.',
              ),
              const SizedBox(height: 12),
              SelectableText(root),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const UiText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const UiText('Find exact duplicates'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => reviewing = false);
    if (accepted != true || selectedRevision != revision) return;
    final id =
        'duplicate-analysis-${DateTime.now().microsecondsSinceEpoch}-${++sequence}';
    setState(() {
      busy = true;
      requestId = id;
      cancelRequested = false;
      cancelled = false;
      result = null;
      message = null;
    });
    try {
      final raw = await widget.invoke('storage.duplicates', {
        'path': root,
        'maxEntries': 10000,
        'maxHashMiB': 512,
      }, requestId: id);
      final parsed = DuplicateAnalysis.parse(raw, root);
      if (mounted && revision == selectedRevision)
        setState(() {
          result = parsed;
          message = null;
        });
      if (mounted && revision == selectedRevision) {
        notifyOperation(context, 'success', 'storage.duplicates');
      }
    } catch (error) {
      if (!mounted || revision != selectedRevision) return;
      final stopped =
          error is PlatformException && error.code == 'ENGINE_CANCELLED';
      final code = error is StateError
          ? error.message.toString().split(':').first
          : '';
      setState(() {
        result = null;
        cancelled = stopped;
        message = stopped
            ? 'Stopped waiting for analysis. This does not prove that all engine reads have stopped.'
            : error is FormatException
            ? 'Duplicate analysis response is invalid. No result was accepted.'
            : {
                'INVALID_ARGUMENT',
                'PATH_NOT_FOUND',
                'ACCESS_DENIED',
                'REPARSE_NOT_ALLOWED',
              }.contains(code)
            ? 'The selected folder is unavailable or unsupported. Check the path and access, then retry.'
            : 'Duplicate analysis could not complete. No files were changed. Retry when the engine is available.';
      });
      notifyOperation(
        context,
        stopped ? 'cancelled' : 'error',
        'storage.duplicates',
      );
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          requestId = null;
          cancelRequested = false;
          if (revision != selectedRevision) {
            message = null;
            cancelled = false;
          }
        });
    }
  }

  Widget metric(String label, int value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text('${localize(context, label)}: $value'),
  );

  @override
  Widget build(BuildContext context) {
    final data = result;
    return Scaffold(
      appBar: inspectionAppBar(context, 'Duplicate analysis'),
      body: Focus(
        focusNode: pagingFocus,
        onKeyEvent: pageKey,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            UiText(
              'Review exact duplicate files',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const UiText(
              'Read up to 10,000 entries and hash up to 512 MiB in one selected folder. Byte comparison verifies matches. This page never deletes files.',
            ),
            const SizedBox(height: 16),
            LabeledControl(
              label: localize(context, 'Folder path'),
              child: TextField(
                controller: input,
                maxLength: 1024,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onChanged: (_) => changed(),
                onSubmitted: (_) => analyze(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: busy || reviewing ? null : choose,
                  icon: const Icon(Icons.folder_open),
                  label: const UiText('Choose folder'),
                ),
                FilledButton.icon(
                  onPressed: busy || reviewing || input.text.trim().isEmpty
                      ? null
                      : analyze,
                  icon: const Icon(Icons.content_copy_outlined),
                  label: const UiText('Analyze duplicates'),
                ),
                if (busy)
                  OutlinedButton.icon(
                    onPressed: cancelRequested ? null : cancelRead,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: UiText(
                      cancelRequested
                          ? 'Cancellation requested…'
                          : 'Cancel scan',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OperationMotion(
              state: busy
                  ? 'working'
                  : cancelled
                  ? 'cancelled'
                  : message != null
                  ? 'error'
                  : data != null
                  ? 'complete'
                  : 'idle',
            ),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Semantics(liveRegion: true, child: UiText(message!)),
            if (data != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      UiText(
                        'Analyzed folder',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SelectableText(data.root),
                      const SizedBox(height: 12),
                      UiText(
                        data.incomplete
                            ? 'Incomplete duplicate view: some comparisons may be missing.'
                            : 'The bounded duplicate analysis completed.',
                      ),
                      const UiText(
                        'Matches were verified with SHA-256 and byte-for-byte comparison. Files may change after analysis.',
                      ),
                      const SizedBox(height: 12),
                      metric('Duplicate groups', data.groups.length),
                      metric('Hashed bytes', data.hashedBytes),
                      metric('Potential duplicate bytes', data.potentialBytes),
                      const UiText(
                        'Potential space is an estimate from reported matches, not recovered space. No files were deleted or changed.',
                      ),
                      metric(
                        'Changed or unavailable checks',
                        data.changedOrUnavailable,
                      ),
                      metric('Inaccessible entries', data.inaccessible),
                      metric('Reparse points skipped', data.reparseSkipped),
                      metric('Folders beyond depth limit', data.tooDeep),
                      if (data.truncated)
                        const UiText(
                          'The 10,000-entry traversal limit was reached. Unvisited entries may contain more duplicates.',
                        ),
                      if (data.budgetReached)
                        const UiText(
                          'The hash budget or group limit was reached. More matches may exist.',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              UiText(
                'Verified duplicate groups',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (data.groups.isEmpty)
                const UiText(
                  'No exact duplicate groups were reported within these limits. This does not prove that the folder has no duplicates.',
                ),
              for (var index = 0; index < data.groups.length; index++)
                Card(
                  child: ExpansionTile(
                    expansionAnimationStyle:
                        MediaQuery.disableAnimationsOf(context)
                        ? const AnimationStyle(
                            duration: Duration.zero,
                            reverseDuration: Duration.zero,
                          )
                        : null,
                    title: Text(
                      '${localize(context, 'Duplicate group')} ${index + 1}',
                    ),
                    subtitle: Text(
                      '${localize(context, 'Matching files')}: ${data.groups[index].totalMatchingFiles}\n${localize(context, 'Bytes per file')}: ${data.groups[index].size}',
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const UiText(
                        'Verified: SHA-256 and byte-for-byte comparison',
                      ),
                      metric(
                        'Potential duplicate bytes',
                        data.groups[index].reclaimableBytes,
                      ),
                      if (data.groups[index].pathsTruncated)
                        const UiText(
                          'Only the first 20 matching paths are shown.',
                        ),
                      const UiText('Full paths'),
                      for (final path in data.groups[index].paths)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: SelectableText(path),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
