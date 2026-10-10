import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inspection_app_bar.dart';
import 'labeled_controls.dart';
import 'localization.dart';
import 'motion.dart';
import 'notifications.dart';

/// Lexical Windows path normalization only. The engine owns existence, access
/// and reparse checks. This never establishes filesystem identity.
String normalizeAnalysisPath(String input) {
  if (input.isEmpty ||
      input.length > 1024 ||
      input.runes.any((c) => c < 32 || c == 127)) {
    throw const FormatException('Invalid folder path');
  }
  final path = input.replaceAll('/', r'\');
  if (path.startsWith(r'\\?\') || path.startsWith(r'\\.\')) {
    throw const FormatException('Device paths are unsupported');
  }
  String prefix;
  List<String> parts;
  if (RegExp(r'^[A-Za-z]:\\').hasMatch(path)) {
    prefix = '${path[0].toUpperCase()}:\\';
    parts = path.substring(3).split(r'\');
  } else if (path.startsWith(r'\\')) {
    final unc = path.substring(2).split(r'\');
    if (unc.length < 2 || unc[0].isEmpty || unc[1].isEmpty) {
      throw const FormatException('Invalid network root');
    }
    prefix = '\\\\${unc[0]}\\${unc[1]}\\';
    parts = unc.skip(2).toList();
    for (final component in unc.take(2)) {
      if (!_validComponent(component) ||
          component == '.' ||
          component == '..') {
        throw const FormatException('Invalid network root');
      }
    }
  } else {
    throw const FormatException('Absolute folder path required');
  }
  final normalized = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (normalized.isEmpty) throw const FormatException('Outside root');
      normalized.removeLast();
    } else {
      if (!_validComponent(part)) throw const FormatException('Invalid path');
      normalized.add(part);
    }
  }
  return prefix + normalized.join(r'\');
}

bool _validComponent(String value) =>
    !RegExp(r'[<>:"|?*]').hasMatch(value) &&
    !value.endsWith(' ') &&
    !value.endsWith('.');

class AnalysisFile {
  const AnalysisFile(this.path, this.size, this.modifiedUtc);
  final String path;
  final int size;
  final DateTime modifiedUtc;
  String get name => path.split(r'\').last;
}

class StorageAnalysis {
  const StorageAnalysis({
    required this.root,
    required this.fileCount,
    required this.totalBytes,
    required this.emptyFolderCount,
    required this.inaccessible,
    required this.reparseSkipped,
    required this.tooDeep,
    required this.truncated,
    required this.largeFiles,
    required this.emptyFolders,
  });
  final String root;
  final int fileCount,
      totalBytes,
      emptyFolderCount,
      inaccessible,
      reparseSkipped,
      tooDeep;
  final bool truncated;
  final List<AnalysisFile> largeFiles;
  final List<String> emptyFolders;
  bool get incomplete =>
      truncated || inaccessible > 0 || reparseSkipped > 0 || tooDeep > 0;

  factory StorageAnalysis.parse(
    Map<String, dynamic> value,
    String requestedRoot,
  ) {
    const maxEntries = 20000;
    int count(String key, [int max = maxEntries + 1]) {
      final item = value[key];
      if (item is! int || item < 0 || item > max)
        throw const FormatException('Invalid count');
      return item;
    }

    String path(Object? item, {bool rootAllowed = false}) {
      if (item is! String) throw const FormatException('Invalid path');
      final normalized = normalizeAnalysisPath(item);
      final root = normalizeAnalysisPath(requestedRoot);
      final prefix = root.endsWith(r'\') ? root : '$root\\';
      final sameRoot = normalized.toLowerCase() == root.toLowerCase();
      if ((sameRoot && !rootAllowed) ||
          (!sameRoot &&
              !normalized.toLowerCase().startsWith(prefix.toLowerCase()))) {
        throw const FormatException('Outside selected folder');
      }
      return normalized;
    }

    if (value['root'] is! String ||
        normalizeAnalysisPath(value['root'] as String).toLowerCase() !=
            normalizeAnalysisPath(requestedRoot).toLowerCase() ||
        value['scope'] != 'selected-folder-only' ||
        value['mutationPerformed'] != false ||
        value['truncated'] is! bool) {
      throw const FormatException('Invalid analysis scope');
    }
    final fileCount = count('fileCount', maxEntries);
    final total = count('totalBytes', 9223372036854775807);
    final emptyCount = count('emptyFolderCount');
    final files = value['largeFiles'];
    final folders = value['emptyFolders'];
    if (files is! List ||
        files.length != (fileCount < 100 ? fileCount : 100) ||
        folders is! List ||
        folders.length != (emptyCount < 1000 ? emptyCount : 1000)) {
      throw const FormatException('Invalid analysis rows');
    }
    final seen = <String>{};
    var sum = 0;
    var previousSize = total;
    final parsedFiles = <AnalysisFile>[];
    for (final file in files) {
      if (file is! Map) throw const FormatException('Invalid file');
      final name = path(file['path']);
      final size = file['size'];
      final stamp = file['modifiedUtc'];
      if (size is! int ||
          size < 0 ||
          size > previousSize ||
          !seen.add(name.toLowerCase()) ||
          stamp is! String ||
          !RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?Z$',
          ).hasMatch(stamp)) {
        throw const FormatException('Invalid file metadata');
      }
      final date = DateTime.tryParse(stamp);
      if (date == null ||
          date.year < 1 ||
          date.year > 9999 ||
          date.toIso8601String().substring(0, 19) != stamp.substring(0, 19)) {
        throw const FormatException('Invalid timestamp');
      }
      if (size > total - sum) {
        throw const FormatException('Invalid total');
      }
      sum += size;
      previousSize = size;
      parsedFiles.add(AnalysisFile(name, size, date));
    }
    if (sum > total || (fileCount <= 100 && sum != total)) {
      throw const FormatException('Invalid total');
    }
    final parsedFolders = <String>[];
    for (final folder in folders) {
      final name = path(folder, rootAllowed: true);
      if (!seen.add(name.toLowerCase()))
        throw const FormatException('Duplicate path');
      parsedFolders.add(name);
    }
    return StorageAnalysis(
      root: normalizeAnalysisPath(requestedRoot),
      fileCount: fileCount,
      totalBytes: total,
      emptyFolderCount: emptyCount,
      inaccessible: count('inaccessible'),
      reparseSkipped: count('reparseSkipped'),
      tooDeep: count('tooDeep'),
      truncated: value['truncated'] as bool,
      largeFiles: List.unmodifiable(parsedFiles),
      emptyFolders: List.unmodifiable(parsedFolders),
    );
  }
}

typedef StorageAnalysisInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters, {
      required String requestId,
    });

class StorageAnalysisPage extends StatefulWidget {
  const StorageAnalysisPage({
    super.key,
    required this.invoke,
    required this.cancel,
    this.pickFolder,
  });
  final StorageAnalysisInvoke invoke;
  final Future<bool> Function(String requestId) cancel;
  final Future<String?> Function()? pickFolder;
  @override
  State<StorageAnalysisPage> createState() => _StorageAnalysisPageState();
}

class _StorageAnalysisPageState extends State<StorageAnalysisPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final pagingFocus = FocusNode(debugLabel: 'Folder analysis paging');
  StorageAnalysis? result;
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
        title: const UiText('Review folder analysis'),
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
            child: const UiText('Analyze selected folder'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => reviewing = false);
    if (accepted != true || selectedRevision != revision) return;
    final id =
        'storage-analysis-${DateTime.now().microsecondsSinceEpoch}-${++sequence}';
    setState(() {
      busy = true;
      requestId = id;
      cancelRequested = false;
      cancelled = false;
      result = null;
      message = null;
    });
    try {
      final raw = await widget.invoke('storage.analyze', {
        'path': root,
        'maxEntries': 20000,
      }, requestId: id);
      final parsed = StorageAnalysis.parse(raw, root);
      if (mounted && revision == selectedRevision)
        setState(() {
          result = parsed;
          message = null;
        });
      if (mounted && revision == selectedRevision) {
        notifyOperation(context, 'success', 'storage.analyze');
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
            ? 'Folder analysis response is invalid. No result was accepted.'
            : {
                'INVALID_ARGUMENT',
                'PATH_NOT_FOUND',
                'ACCESS_DENIED',
                'REPARSE_NOT_ALLOWED',
              }.contains(code)
            ? 'The selected folder is unavailable or unsupported. Check the path and access, then retry.'
            : 'Folder analysis could not complete. No files were changed. Retry when the engine is available.';
      });
      notifyOperation(
        context,
        stopped ? 'cancelled' : 'error',
        'storage.analyze',
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
      appBar: inspectionAppBar(context, 'Folder analysis'),
      body: Focus(
        focusNode: pagingFocus,
        onKeyEvent: pageKey,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            UiText(
              'Understand one folder',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const UiText(
              'Read-only analysis counts observed files and lists the largest files and empty folders. Nothing is collected until you review a folder.',
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
                  icon: const Icon(Icons.analytics_outlined),
                  label: const UiText('Analyze folder'),
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
                            ? 'Incomplete view: some entries were not examined.'
                            : 'The selected folder traversal completed.',
                      ),
                      const UiText(
                        'Point-in-time metadata only. Files may change after analysis. No files were changed.',
                      ),
                      const SizedBox(height: 12),
                      metric('Observed files', data.fileCount),
                      metric('Observed bytes', data.totalBytes),
                      metric('Observed empty folders', data.emptyFolderCount),
                      metric('Inaccessible entries', data.inaccessible),
                      metric('Reparse points skipped', data.reparseSkipped),
                      metric('Folders beyond depth limit', data.tooDeep),
                      if (data.truncated)
                        const UiText(
                          'The 20,000-entry traversal limit was reached. Totals describe only observed entries.',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              UiText(
                'Largest files',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${localize(context, 'Shown files')}: ${data.largeFiles.length} / ${data.fileCount}',
              ),
              if (data.fileCount > 100)
                const UiText('Only the largest 100 observed files are listed.'),
              if (data.largeFiles.isEmpty)
                const UiText('No files were observed.'),
              for (final file in data.largeFiles)
                Card(
                  child: ExpansionTile(
                    expansionAnimationStyle:
                        MediaQuery.disableAnimationsOf(context)
                        ? const AnimationStyle(
                            duration: Duration.zero,
                            reverseDuration: Duration.zero,
                          )
                        : null,
                    title: Text(file.name),
                    subtitle: Text(
                      '${localize(context, 'Bytes')}: ${file.size}',
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const UiText('Full path'),
                      SelectableText(file.path),
                      const SizedBox(height: 8),
                      const UiText('File modified at UTC'),
                      SelectableText(file.modifiedUtc.toIso8601String()),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              UiText(
                'Empty folders',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${localize(context, 'Shown folders')}: ${data.emptyFolders.length} / ${data.emptyFolderCount}',
              ),
              if (data.emptyFolderCount > 1000)
                const UiText(
                  'Only the first 1,000 observed empty folders are listed.',
                ),
              const UiText(
                'Empty means no entries were observed, including hidden entries. Inaccessible folders are not declared empty.',
              ),
              if (data.emptyFolders.isEmpty)
                const UiText('No empty folders were observed.'),
              for (final folder in data.emptyFolders)
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
                      folder.split(r'\').last.isEmpty
                          ? folder
                          : folder.split(r'\').last,
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const UiText('Full path'),
                      SelectableText(folder),
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
