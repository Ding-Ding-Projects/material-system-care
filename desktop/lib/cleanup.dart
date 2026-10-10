import 'package:flutter/material.dart';
import 'localization.dart';

enum CleanupKind { scan, receipt, history }

class CleanupFile {
  const CleanupFile(this.index, this.path, this.bytes, this.state, this.reason);
  final int index;
  final String path;
  final int? bytes;
  final String state;
  final String? reason;
  String get name => path.split(RegExp(r'[/\\]')).last;
}

class CleanupReceipt {
  const CleanupReceipt(
    this.id,
    this.count,
    this.moved,
    this.restored,
    this.conflicts,
    this.skipped,
    this.unreadable,
  );
  final String id;
  final int? count, moved, restored, conflicts, skipped;
  final bool unreadable;
}

class CleanupResult {
  const CleanupResult(
    this.kind,
    this.files,
    this.receipts,
    this.receiptId,
    this.partial,
    this.cancelled,
    this.plannedCount,
    this.truncated,
    this.excluded,
  );
  final CleanupKind kind;
  final List<CleanupFile> files;
  final List<CleanupReceipt> receipts;
  final String? receiptId;
  final bool partial, cancelled, truncated;
  final int? plannedCount;
  final int excluded;
  bool get canRestore => files.any(
    (file) => const {
      'quarantined',
      'conflict',
      'pending',
      'restoring',
      'unresolved',
    }.contains(file.state),
  );
  String searchText(int index, BuildContext context) {
    if (kind == CleanupKind.history) return receipts[index].id;
    final file = files[index];
    return '${file.path} ${localize(context, cleanupStateLabel(file.state))} ${file.reason == null ? '' : localize(context, cleanupReasonLabel(file.reason!))}';
  }

  static int? count(dynamic value) => value is int && value >= 0 ? value : null;
  static String? text(dynamic value) =>
      value is String &&
          value.isNotEmpty &&
          value.length <= 1024 &&
          !value.runes.any((c) => c < 32)
      ? value
      : null;
  static CleanupResult parse(String method, Map<String, dynamic> data) {
    final kind = method == 'cleanup.scan'
        ? CleanupKind.scan
        : method == 'cleanup.history'
        ? CleanupKind.history
        : CleanupKind.receipt;
    final raw =
        data[kind == CleanupKind.scan
            ? 'targets'
            : kind == CleanupKind.history
            ? 'receipts'
            : 'items'];
    if (raw is! List || raw.length > 1000)
      throw const FormatException('Invalid cleanup results');
    final files = <CleanupFile>[];
    final receipts = <CleanupReceipt>[];
    for (var index = 0; index < raw.length; index++) {
      final row = raw[index];
      if (row is! Map) throw const FormatException('Invalid cleanup row');
      if (kind == CleanupKind.history) {
        final id = text(row['receiptId'] ?? row['id']);
        if (id == null) throw const FormatException('Invalid cleanup receipt');
        receipts.add(
          CleanupReceipt(
            id,
            count(row['itemCount']),
            count(row['quarantined']),
            count(row['restored']),
            count(row['conflicts']),
            count(row['skipped']),
            row['state'] == 'unreadable',
          ),
        );
      } else {
        final target = row['target'] is Map ? row['target'] as Map : row;
        final path = text(target['path']);
        if (path == null) throw const FormatException('Invalid cleanup path');
        files.add(
          CleanupFile(
            index,
            path,
            count(target['size']),
            kind == CleanupKind.scan
                ? 'planned'
                : text(row['state']) ?? 'unknown',
            text(row['reason']),
          ),
        );
      }
    }
    return CleanupResult(
      kind,
      List.unmodifiable(files),
      List.unmodifiable(receipts),
      text(data['receiptId']),
      data['partial'] == true,
      data['cancelled'] == true,
      count(data['plannedCount']),
      data['truncated'] == true,
      (count(data['inaccessible']) ?? 0) +
          (count(data['reparseSkipped']) ?? 0) +
          (count(data['unavailable']) ?? 0),
    );
  }
}

String cleanupStateLabel(String state) => switch (state) {
  'planned' => 'Ready for review',
  'quarantined' => 'In recovery storage',
  'restored' => 'Restored',
  'skipped' => 'Skipped',
  'conflict' => 'Needs attention',
  'pending' => 'Move not confirmed',
  'restoring' => 'Restore not confirmed',
  'unresolved' => 'Unresolved',
  _ => 'State unavailable',
};

String cleanupReasonLabel(String reason) => switch (reason) {
  'TARGET_CHANGED' =>
    'The file changed after review. Scan again before cleanup.',
  'RESTORE_CONFLICT' =>
    'The original path is occupied. Recovery data was retained.',
  'RECOVERY_CHANGED' =>
    'The recovery file changed. It was retained for inspection.',
  'RECOVERY_FILE_MISSING' =>
    'The recovery file is missing. Restoration is not confirmed.',
  'INTERRUPTED_RESTORE_RECONCILED' =>
    'An interrupted restoration was verified against the original file.',
  'cancelled' => 'The operation stopped before this file completed.',
  'REPARSE_NOT_ALLOWED' => 'A link or reparse point prevented this operation.',
  'HARDLINK_NOT_ALLOWED' => 'A file with multiple links was excluded.',
  'SCOPE_NOT_ALLOWED' => 'The file is outside the approved cleanup scope.',
  _ =>
    reason.startsWith('FILE_UNAVAILABLE')
        ? 'The file could not be accessed or moved. Recovery records were retained.'
        : 'The engine reported a condition that needs review.',
};

class CleanupResults extends StatelessWidget {
  const CleanupResults({
    super.key,
    required this.result,
    required this.visibleIndexes,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onRestore,
  });
  final CleanupResult result;
  final Set<int> visibleIndexes, selected;
  final bool busy;
  final void Function(int, bool) onSelect;
  final ValueChanged<String> onRestore;
  Widget countLine(BuildContext context, String label, int? value) => Text(
    '${localize(context, label)}: ${value ?? localize(context, 'Unavailable')}',
  );

  @override
  Widget build(BuildContext context) {
    final files = result.files
        .where((file) => visibleIndexes.contains(file.index))
        .toList();
    final receipts = result.receipts
        .asMap()
        .entries
        .where((row) => visibleIndexes.contains(row.key))
        .map((row) => row.value)
        .toList();
    return ListView(
      key: const ValueKey('cleanup-results-list'),
      children: [
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiText(
                  result.kind == CleanupKind.scan
                      ? 'Cleanup plan'
                      : result.kind == CleanupKind.history
                      ? 'Recovery history'
                      : 'Recorded cleanup result',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (result.kind == CleanupKind.scan)
                  const UiText(
                    'Only selected files will move to recovery. Nothing has moved yet.',
                  ),
                if (result.kind == CleanupKind.receipt)
                  const UiText(
                    'These are recorded outcomes. Current file availability is checked during restoration.',
                  ),
                if (result.cancelled)
                  const UiText(
                    'Operation stopped. Completed moves and recovery records were retained.',
                  ),
                if (result.partial)
                  const UiText(
                    'Some files did not complete. Review each recorded state before retrying.',
                  ),
                if (result.truncated)
                  const UiText(
                    'The scan limit was reached. This plan contains only the reviewed subset.',
                  ),
                if (result.excluded > 0)
                  countLine(
                    context,
                    'Excluded or unavailable entries',
                    result.excluded,
                  ),
                countLine(
                  context,
                  result.kind == CleanupKind.history
                      ? 'Recorded receipts'
                      : 'Recorded files',
                  result.kind == CleanupKind.history
                      ? result.receipts.length
                      : result.files.length,
                ),
                if (result.kind == CleanupKind.scan)
                  countLine(context, 'Selected files', selected.length),
                if (result.plannedCount != null)
                  countLine(
                    context,
                    'Selected files requested',
                    result.plannedCount,
                  ),
                if (result.plannedCount != null &&
                    result.plannedCount! > result.files.length)
                  countLine(
                    context,
                    'Files without a completed result',
                    result.plannedCount! - result.files.length,
                  ),
                if (result.receiptId != null) ...[
                  const UiText('Receipt identifier'),
                  SelectableText(result.receiptId!),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy || !result.canRestore
                        ? null
                        : () => onRestore(result.receiptId!),
                    icon: const Icon(Icons.restore),
                    label: const UiText('Review restoration'),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (result.files.isEmpty && result.receipts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: UiText(
              result.kind == CleanupKind.scan
                  ? 'No eligible temporary files were found.'
                  : result.kind == CleanupKind.history
                  ? 'No recovery receipts were found.'
                  : 'This result contains no recorded files.',
            ),
          ),
        if (files.isEmpty &&
            receipts.isEmpty &&
            (result.files.isNotEmpty || result.receipts.isNotEmpty))
          const Padding(
            padding: EdgeInsets.all(16),
            child: UiText('No matching cleanup records.'),
          ),
        for (final file in files)
          Card(
            key: ValueKey('cleanup-file-${file.index}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result.kind == CleanupKind.scan)
                  CheckboxListTile(
                    value: selected.contains(file.index),
                    onChanged: busy
                        ? null
                        : (value) => onSelect(file.index, value == true),
                    title: Text(file.name),
                    subtitle: countLine(context, 'Bytes', file.bytes),
                  )
                else
                  ListTile(
                    title: Text(file.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        countLine(context, 'Bytes', file.bytes),
                        UiText(cleanupStateLabel(file.state)),
                      ],
                    ),
                  ),
                if (file.reason != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: UiText(cleanupReasonLabel(file.reason!)),
                  ),
                ExpansionTile(
                  expansionAnimationStyle:
                      MediaQuery.disableAnimationsOf(context)
                      ? const AnimationStyle(
                          duration: Duration.zero,
                          reverseDuration: Duration.zero,
                        )
                      : null,
                  title: const UiText('File details'),
                  childrenPadding: const EdgeInsets.all(16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UiText('Full original path'),
                    SelectableText(file.path),
                    const SizedBox(height: 8),
                    Text(
                      '${localize(context, 'Recorded state')}: ${localize(context, cleanupStateLabel(file.state))}',
                    ),
                    if (file.reason != null) ...[
                      const UiText('Engine reason code'),
                      SelectableText(file.reason!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        for (final receipt in receipts)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiText(
                    'Recovery receipt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const UiText('Receipt identifier'),
                  SelectableText(receipt.id),
                  if (receipt.unreadable)
                    const UiText(
                      'This recovery record is unavailable. No restoration is confirmed.',
                    )
                  else ...[
                    countLine(context, 'Recorded files', receipt.count),
                    countLine(context, 'In recovery storage', receipt.moved),
                    countLine(context, 'Restored', receipt.restored),
                    countLine(context, 'Needs attention', receipt.conflicts),
                    countLine(context, 'Skipped', receipt.skipped),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy || receipt.unreadable
                        ? null
                        : () => onRestore(receipt.id),
                    icon: const Icon(Icons.restore),
                    label: const UiText('Review restoration'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
