import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inspection_app_bar.dart';
import 'localization.dart';
import 'motion.dart';
import 'notifications.dart';
import 'provenance.dart';

const _safeInteger = 9007199254740991;
int _count(Object? value, {int max = _safeInteger, int min = 0}) {
  if (value is! int || value < min || value > max)
    throw const FormatException('Invalid measurement');
  return value;
}

String _text(Object? value, int max) {
  if (value is! String ||
      value.isEmpty ||
      value.length > max ||
      value.runes.any((c) => c < 32 || c == 127))
    throw const FormatException('Invalid description');
  return value;
}

class MemorySample {
  const MemorySample(this.total, this.available, this.loadPercent);
  final int total, available, loadPercent;
  int get used => total - available;
}

class DriveSample {
  const DriveSample(
    this.id,
    this.ready,
    this.total,
    this.free,
    this.format,
    this.reason,
  );
  final String id;
  final bool ready;
  final int? total, free;
  final String? format;
  final String? reason;
}

class SystemSample {
  const SystemSample(
    this.measuredAt,
    this.fixtureDataRoot,
    this.logicalProcessors,
    this.description,
    this.architecture,
    this.memory,
    this.drives,
  );
  final DateTime measuredAt;
  final bool fixtureDataRoot;
  final int logicalProcessors;
  final String description, architecture;
  final MemorySample? memory;
  final List<DriveSample> drives;
  bool get partial => memory == null || drives.any((d) => !d.ready);

  factory SystemSample.parse(Map<String, dynamic> value) {
    final stamp = value['measuredAt'];
    if (stamp is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,7})?(Z|\+00:00)$',
        ).hasMatch(stamp) ||
        value['fixtureDataRoot'] is! bool ||
        value['measurementSource'] != 'live-machine') {
      throw const FormatException('Invalid measurement source');
    }
    final time = DateTime.tryParse(stamp);
    if (time == null ||
        time.year < 1 ||
        time.year > 9999 ||
        time.toIso8601String().substring(0, 19) != stamp.substring(0, 19))
      throw const FormatException('Invalid sample time');
    final cpu = value['cpu'],
        os = value['os'],
        rawMemory = value['memory'],
        rawDrives = value['drives'];
    if (cpu is! Map ||
        os is! Map ||
        rawMemory is! Map ||
        rawMemory['available'] is! bool ||
        rawDrives is! List ||
        rawDrives.length > 26)
      throw const FormatException('Invalid snapshot shape');
    MemorySample? memory;
    if (rawMemory['available'] == true) {
      final total = _count(rawMemory['totalBytes'], min: 1);
      final available = _count(rawMemory['availableBytes'], max: total);
      memory = MemorySample(
        total,
        available,
        _count(rawMemory['loadPercent'], max: 100),
      );
    } else {
      for (final key in ['totalBytes', 'availableBytes', 'loadPercent']) {
        if (!rawMemory.containsKey(key) || rawMemory[key] != null)
          throw const FormatException('Unavailable memory has values');
      }
    }
    final ids = <String>{};
    final drives = <DriveSample>[];
    for (final raw in rawDrives) {
      if (raw is! Map || raw['ready'] is! bool)
        throw const FormatException('Invalid drive');
      final id = _text(raw['id'], 3);
      if (!RegExp(r'^[A-Za-z]:\\$').hasMatch(id) ||
          raw['name'] != id ||
          !ids.add(id.toUpperCase()))
        throw const FormatException('Invalid drive identity');
      if (raw['ready'] == true) {
        final total = _count(raw['totalBytes']);
        final free = _count(raw['freeBytes'], max: total);
        if (raw['unavailableReason'] != null)
          throw const FormatException('Contradictory drive state');
        drives.add(
          DriveSample(id, true, total, free, _text(raw['format'], 64), null),
        );
      } else {
        if (raw['totalBytes'] != null ||
            raw['freeBytes'] != null ||
            raw['format'] != null)
          throw const FormatException('Unavailable drive has capacity');
        final reason = raw['unavailableReason'];
        if (reason != null &&
            reason != 'Volume metadata is unavailable.' &&
            reason != 'Volume access is unavailable.')
          throw const FormatException('Invalid unavailable reason');
        drives.add(
          DriveSample(
            id,
            false,
            null,
            null,
            null,
            reason as String? ?? 'Drive is not ready.',
          ),
        );
      }
    }
    return SystemSample(
      time,
      value['fixtureDataRoot'] as bool,
      _count(cpu['logicalProcessors'], min: 1, max: 65536),
      _text(os['description'], 1024),
      _text(os['architecture'], 64),
      memory,
      List.unmodifiable(drives),
    );
  }
}

typedef SystemOverviewInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class SystemOverviewPage extends StatefulWidget {
  const SystemOverviewPage({super.key, required this.invoke, this.now});
  final SystemOverviewInvoke invoke;
  final DateTime Function()? now;
  @override
  State<SystemOverviewPage> createState() => _SystemOverviewPageState();
}

class _SystemOverviewPageState extends State<SystemOverviewPage> {
  final scroll = ScrollController();
  final pagingFocus = FocusNode(debugLabel: 'System overview paging');
  Map<String, dynamic>? ping;
  SystemSample? sample;
  bool busy = false;
  String? failure;

  @override
  void initState() {
    super.initState();
    loadProvenance();
  }

  Future<void> loadProvenance() async {
    try {
      final value = await widget.invoke('engine.ping', {});
      if (mounted) setState(() => ping = value);
    } catch (_) {
      if (mounted) setState(() => ping = null);
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    pagingFocus.dispose();
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
    final pos = scroll.position;
    final target =
        (pos.pixels +
                pos.viewportDimension *
                    (key == LogicalKeyboardKey.pageDown ? .8 : -.8))
            .clamp(pos.minScrollExtent, pos.maxScrollExtent);
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

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      failure = null;
      sample = null;
    });
    try {
      final value = SystemSample.parse(
        await widget.invoke('system.snapshot', {}),
      );
      if (!mounted) return;
      setState(() => sample = value);
      notifyOperation(context, 'success', 'system.snapshot');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        sample = null;
        failure =
            'Machine measurements are unavailable or invalid. Refresh to try again.';
      });
      notifyOperation(context, 'error', 'system.snapshot');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget indicator(double value, String label) => TweenAnimationBuilder<double>(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250),
    tween: Tween(begin: 0, end: value),
    builder: (_, progress, __) => LinearProgressIndicator(
      value: progress,
      semanticsLabel: localize(context, label),
      semanticsValue: '${(value * 100).round()}%',
    ),
  );
  Widget metric(String label, Object value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('${localize(context, label)}: $value'),
  );
  Widget panel(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiText(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final data = sample;
    final age = data == null
        ? null
        : (widget.now?.call() ?? DateTime.now())
              .toUtc()
              .difference(data.measuredAt)
              .inSeconds;
    return Scaffold(
      appBar: inspectionAppBar(context, 'Machine overview'),
      body: Focus(
        focusNode: pagingFocus,
        onKeyEvent: pageKey,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            BuildProvenance(ping: ping),
            const SizedBox(height: 16),
            const UiText(
              'Refresh for a point-in-time sample of this machine. No automatic polling or benchmark runs.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: const UiText('Refresh measurements'),
              ),
            ),
            const SizedBox(height: 16),
            OperationMotion(
              state: busy
                  ? 'working'
                  : failure != null
                  ? 'error'
                  : data != null
                  ? 'complete'
                  : 'idle',
            ),
            if (busy) const LinearProgressIndicator(),
            if (failure != null)
              Semantics(liveRegion: true, child: UiText(failure!)),
            if (data != null) ...[
              panel('Sample details', [
                const UiText('Measured at UTC'),
                SelectableText(data.measuredAt.toIso8601String()),
                if (age! < 0)
                  const UiText('The sample time is ahead of the display clock.')
                else
                  metric('Sample age at this render (seconds)', age),
                const UiText(
                  'Age changes only when this view renders. Refresh to request a new sample; the build updated-at value is separate.',
                ),
                UiText(
                  data.partial
                      ? 'Some measurements are unavailable. Available readings remain shown.'
                      : 'The reported measurement fields are available.',
                ),
                if (data.fixtureDataRoot)
                  const UiText(
                    'An isolated data directory is in use. These measurements still come from the live machine.',
                  ),
              ]),
              panel('Operating system and processors', [
                const UiText('Operating system'),
                SelectableText(data.description),
                metric('Architecture', data.architecture),
                metric('Logical processors', data.logicalProcessors),
                const UiText(
                  'Logical processor count is not CPU utilization. No utilization or health score is measured here.',
                ),
              ]),
              panel(
                'Physical memory',
                data.memory == null
                    ? [
                        const UiText(
                          'Physical memory measurements are unavailable.',
                        ),
                      ]
                    : [
                        metric(
                          'Reported memory load',
                          '${data.memory!.loadPercent}%',
                        ),
                        indicator(
                          data.memory!.loadPercent / 100,
                          'Reported memory load',
                        ),
                        metric('Total bytes', data.memory!.total),
                        metric('Available bytes', data.memory!.available),
                        metric('Used bytes', data.memory!.used),
                      ],
              ),
              const SizedBox(height: 16),
              UiText(
                'Drive capacity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const UiText(
                'Capacity describes this sample, not disk health or recoverable cleanup space.',
              ),
              if (data.drives.isEmpty) const UiText('No drives were reported.'),
              for (final drive in data.drives)
                Card(
                  child: ExpansionTile(
                    expansionAnimationStyle:
                        MediaQuery.disableAnimationsOf(context)
                        ? const AnimationStyle(
                            duration: Duration.zero,
                            reverseDuration: Duration.zero,
                          )
                        : null,
                    title: Text(drive.id),
                    subtitle: UiText(
                      drive.ready
                          ? 'Capacity available'
                          : 'Capacity unavailable',
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: drive.ready
                        ? [
                            SelectableText(drive.id),
                            metric('File system', drive.format!),
                            metric('Total bytes', drive.total!),
                            metric('Free bytes', drive.free!),
                            metric('Used bytes', drive.total! - drive.free!),
                            if (drive.total! > 0)
                              indicator(
                                (drive.total! - drive.free!) / drive.total!,
                                'Used drive capacity',
                              )
                            else
                              const UiText(
                                'This drive reported zero capacity.',
                              ),
                          ]
                        : [UiText(drive.reason!)],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
