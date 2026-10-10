import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cleanup.dart';
import 'storage_analysis.dart' show normalizeAnalysisPath;
import 'inspection_app_bar.dart';
import 'localization.dart';
import 'labeled_controls.dart';
import 'motion.dart';
import 'notifications.dart';

typedef CleanupInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters, {
      String? requestId,
    });

class CleanupPlan {
  CleanupPlan(this.result, this.root, this.expires);
  final CleanupResult result;
  final String root;
  final DateTime expires;
  factory CleanupPlan.parse(
    Map<String, dynamic> data, {
    required bool fixture,
  }) {
    final result = CleanupResult.parse('cleanup.scan', data);
    final root = data['root'];
    final expiry = data['expiresUtc'];
    if (data['fixture'] != fixture ||
        data['category'] != 'aged-user-temp-files' ||
        root is! String ||
        expiry is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?Z$',
        ).hasMatch(expiry) ||
        data['minimumAgeDays'] != 7 ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(result.planId!))
      throw const FormatException('Invalid cleanup scope');
    final normalized = normalizeAnalysisPath(root);
    if (normalized.startsWith(r'\\') || normalized.length <= 3)
      throw const FormatException('Invalid cleanup root');
    final expires = DateTime.tryParse(expiry);
    if (expires == null ||
        expires.toIso8601String().substring(0, 19) != expiry.substring(0, 19) ||
        expires.isBefore(DateTime.now().toUtc()) ||
        expires.isAfter(
          DateTime.now().toUtc().add(const Duration(days: 1, minutes: 1)),
        ))
      throw const FormatException('Expired cleanup plan');
    var sum = 0;
    final paths = <String>{};
    for (final file in result.files) {
      final path = normalizeAnalysisPath(file.path).toLowerCase();
      if (!path.startsWith('${normalized.toLowerCase()}\\') ||
          file.bytes == null ||
          file.bytes! > 512 * 1024 * 1024 ||
          !paths.add(path))
        throw const FormatException('Invalid cleanup target');
      sum += file.bytes!;
    }
    if (data['totalBytes'] is! int ||
        data['totalBytes'] != sum ||
        sum > 512 * 1024 * 1024)
      throw const FormatException('Invalid cleanup total');
    for (final key in ['inaccessible', 'reparseSkipped', 'unavailable']) {
      if (data[key] is! int || data[key] < 0 || data[key] > 20000)
        throw const FormatException('Invalid cleanup count');
    }
    return CleanupPlan(result, normalized, expires);
  }
}

class CleanupWorkspace extends StatefulWidget {
  const CleanupWorkspace({
    super.key,
    required this.invoke,
    required this.cancel,
    required this.onRecovery,
    this.fixture = false,
  });
  final CleanupInvoke invoke;
  final Future<bool> Function(String) cancel;
  final ValueChanged<String?> onRecovery;
  final bool fixture;
  @override
  State<CleanupWorkspace> createState() => _CleanupWorkspaceState();
}

class _CleanupWorkspaceState extends State<CleanupWorkspace> {
  final search = TextEditingController();
  final scroll = ScrollController();
  final focus = FocusNode(debugLabel: 'Cleanup paging');
  final selected = <int>{};
  CleanupResult? result;
  CleanupPlan? plan;
  bool busy = false,
      reviewing = false,
      cancelRequested = false,
      cancelled = false,
      regex = false;
  String? activeId, failure, patternError;
  int sequence = 0;
  @override
  void dispose() {
    final id = activeId;
    if (id != null) widget.cancel(id).catchError((Object _) => false);
    search.dispose();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  KeyEventResult pageKey(FocusNode node, KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !scroll.hasClients ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null)
      return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.pageDown && key != LogicalKeyboardKey.pageUp)
      return KeyEventResult.ignored;
    final p = scroll.position;
    final target =
        (p.pixels +
                p.viewportDimension *
                    (key == LogicalKeyboardKey.pageDown ? .8 : -.8))
            .clamp(p.minScrollExtent, p.maxScrollExtent);
    focus.requestFocus();
    if (MediaQuery.disableAnimationsOf(context))
      scroll.jumpTo(target);
    else
      scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    return KeyEventResult.handled;
  }

  Set<int> get visible {
    if (result == null || patternError != null) return {};
    return result!.files
        .where((f) {
          final text = result!.searchText(f.index, context);
          return regex
              ? RegExp(search.text, caseSensitive: false).hasMatch(text)
              : text.toLowerCase().contains(search.text.toLowerCase());
        })
        .map((f) => f.index)
        .toSet();
  }

  void queryChanged(String value) {
    setState(() {
      try {
        if (regex) RegExp(value);
        patternError = null;
      } catch (_) {
        patternError = 'Invalid regular expression';
      }
    });
  }

  Future<void> scan() async {
    if (busy || reviewing) return;
    final id =
        'cleanup-read-${DateTime.now().microsecondsSinceEpoch}-${++sequence}';
    setState(() {
      busy = true;
      activeId = id;
      cancelRequested = false;
      cancelled = false;
      failure = null;
      result = null;
      plan = null;
      selected.clear();
    });
    try {
      final data = await widget.invoke('cleanup.scan', {
        'minimumAgeDays': 7,
        'maxEntries': 10000,
        'maxHashMiB': 512,
      }, requestId: id);
      final parsed = CleanupPlan.parse(data, fixture: widget.fixture);
      if (!mounted || activeId != id) return;
      setState(() {
        plan = parsed;
        result = parsed.result;
      });
      notifyOperation(context, 'success', 'cleanup.scan');
    } catch (e) {
      if (!mounted || activeId != id) return;
      if (e is PlatformException && e.code == 'ENGINE_CANCELLED') {
        setState(() => cancelled = true);
        notifyOperation(context, 'cancelled', 'cleanup.scan');
      } else {
        setState(
          () => failure =
              'Cleanup results are invalid or unavailable. Scan again before selecting files.',
        );
        notifyOperation(context, 'error', 'cleanup.scan');
      }
    } finally {
      if (mounted && activeId == id)
        setState(() {
          busy = false;
          activeId = null;
          cancelRequested = false;
        });
    }
  }

  Future<void> cancelRead() async {
    final id = activeId;
    if (id == null || cancelRequested) return;
    setState(() => cancelRequested = true);
    try {
      final accepted = await widget.cancel(id);
      if (!accepted && mounted && activeId == id)
        setState(() {
          cancelRequested = false;
          failure =
              'Cancellation was not accepted. The scan may still be running.';
        });
    } catch (_) {
      if (mounted && activeId == id)
        setState(() {
          cancelRequested = false;
          failure =
              'Cancellation was not accepted. The scan may still be running.';
        });
    }
  }

  Future<void> apply() async {
    final reviewed = plan;
    if (busy || reviewing || reviewed == null || selected.isEmpty) return;
    if (!reviewed.expires.isAfter(DateTime.now().toUtc())) {
      setState(() {
        plan = null;
        result = null;
        selected.clear();
        failure =
            'The cleanup plan expired. Scan again before selecting files.';
      });
      return;
    }
    final indexes = selected.toList()..sort();
    if (indexes.any((i) => i < 0 || i >= reviewed.result.files.length)) return;
    setState(() => reviewing = true);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const UiText('Move selected temporary files to recovery?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiText(
                'Only selected temporary files will move to recovery.',
              ),
              for (final i in indexes)
                SelectableText(reviewed.result.files[i].path),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const UiText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const UiText('Confirm selected action'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => reviewing = false);
    if (accepted != true) return;
    if (!identical(plan, reviewed) ||
        !reviewed.expires.isAfter(DateTime.now().toUtc())) {
      setState(() {
        plan = null;
        result = null;
        selected.clear();
        failure =
            'The cleanup plan expired. Scan again before selecting files.';
      });
      return;
    }
    setState(() {
      busy = true;
      failure = null;
      result = null;
      plan = null;
      selected.clear();
    });
    try {
      final data = await widget.invoke('cleanup.apply', {
        'planId': reviewed.result.planId,
        'targetIndexes': indexes,
        'confirmed': true,
      });
      final parsed = CleanupResult.parse('cleanup.apply', data);
      final approved = {
        for (final i in indexes)
          reviewed.result.files[i].path.toLowerCase():
              reviewed.result.files[i].bytes,
      };
      final seen = <String>{};
      if (parsed.files.any(
        (f) =>
            !approved.containsKey(f.path.toLowerCase()) ||
            approved[f.path.toLowerCase()] != f.bytes ||
            !seen.add(f.path.toLowerCase()),
      ))
        throw const FormatException('Unexpected receipt target');
      if (parsed.receiptId != reviewed.result.planId ||
          parsed.plannedCount != indexes.length)
        throw const FormatException('Mismatched receipt');
      final quarantined = parsed.files
          .where((file) => file.state == 'quarantined')
          .length;
      if (parsed.partial != (quarantined != indexes.length)) {
        throw const FormatException('Contradictory partial receipt');
      }
      if (!mounted) return;
      setState(() => result = parsed);
      notifyOperation(
        context,
        parsed.cancelled
            ? 'cancelled'
            : parsed.partial
            ? 'error'
            : 'success',
        'cleanup.apply',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => failure =
              'Cleanup could not be confirmed. Review recovery history before retrying.',
        );
        notifyOperation(context, 'error', 'cleanup.apply');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = <Widget>[
      const UiText('Recoverable temporary-file cleanup'),
      if (widget.fixture) const UiText('Cleanup verification · 清理驗證'),
      const UiText(
        'Only aged files in the supported current-user temporary folder are eligible. No permanent deletion is requested.',
      ),
      const UiText(
        'Scan limits: 7 days old, 10,000 entries, 512 MiB hashed, up to 1,000 targets. This is a bounded plan, not a complete disk inventory.',
      ),
      if (plan != null) ...[
        const UiText('Approved cleanup root'),
        SelectableText(plan!.root),
        Text(
          '${localize(context, 'Plan expires at UTC')}: ${plan!.expires.toIso8601String()}',
        ),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: busy || reviewing ? null : scan,
            child: const UiText('Scan recoverable cleanup'),
          ),
          if (activeId != null)
            OutlinedButton(
              onPressed: cancelRequested ? null : cancelRead,
              child: UiText(
                cancelRequested ? 'Cancellation requested…' : 'Cancel scan',
              ),
            ),
          OutlinedButton(
            onPressed: busy || reviewing ? null : () => widget.onRecovery(null),
            child: const UiText('Recovery history'),
          ),
          if (plan != null) ...[
            FilledButton.tonal(
              onPressed: busy || reviewing || selected.isEmpty ? null : apply,
              child: const UiText('Apply selected cleanup targets'),
            ),
            OutlinedButton(
              onPressed: busy || reviewing
                  ? null
                  : () => setState(() => selected.addAll(visible)),
              child: const UiText('Select visible targets'),
            ),
            TextButton(
              onPressed: busy || reviewing
                  ? null
                  : () => setState(selected.clear),
              child: const UiText('Clear selection'),
            ),
          ],
        ],
      ),
      LabeledSearchBar(
        label: localize(context, 'Filter these records'),
        controller: search,
        onChanged: queryChanged,
        leading: const Icon(Icons.search),
        trailing: [
          MenuAnchor(
            builder: (c, controller, child) => IconButton(
              tooltip: localize(context, 'Regular expression builder'),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.data_object),
            ),
            menuChildren: [
              CheckboxMenuButton(
                value: regex,
                onChanged: (v) {
                  setState(() => regex = v ?? false);
                  queryChanged(search.text);
                },
                child: const UiText('Use regular expression'),
              ),
              for (final e in {
                'Contains text': '.*text.*',
                'Starts with': '^text',
                'Ends with': r'text$',
                'Digits': r'\d+',
                'One of': '(first|second)',
              }.entries)
                MenuItemButton(
                  onPressed: () {
                    search.text = e.value;
                    regex = true;
                    queryChanged(e.value);
                  },
                  child: UiText(e.key),
                ),
            ],
          ),
        ],
      ),
      if (patternError != null) UiText(patternError!),
      OperationMotion(
        state: busy
            ? 'working'
            : cancelled
            ? 'cancelled'
            : failure != null
            ? 'error'
            : result != null
            ? 'success'
            : 'idle',
      ),
      if (busy) const LinearProgressIndicator(),
      if (cancelled)
        const UiText(
          'Stopped waiting for cleanup scan. This does not prove that all engine reads have stopped.',
        ),
      if (failure != null) Semantics(liveRegion: true, child: UiText(failure!)),
      const SizedBox(height: 12),
    ];
    return Scaffold(
      appBar: inspectionAppBar(context, 'Recoverable cleanup'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Focus(
          focusNode: focus,
          onKeyEvent: pageKey,
          child: result == null
              ? ListView(controller: scroll, children: header)
              : CleanupResults(
                  result: result!,
                  visibleIndexes: visible,
                  selected: selected,
                  busy: busy || reviewing,
                  onSelect: (i, v) =>
                      setState(() => v ? selected.add(i) : selected.remove(i)),
                  onRestore: widget.onRecovery,
                  header: header,
                  controller: scroll,
                ),
        ),
      ),
    );
  }
}
