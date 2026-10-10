import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inspection_app_bar.dart';
import 'localization.dart';
import 'motion.dart';
import 'notifications.dart';

class DriverPackage {
  const DriverPackage(
    this.id,
    this.originalName,
    this.provider,
    this.className,
    this.version,
    this.signer,
  );
  final String id;
  final String? originalName, provider, className, version, signer;
}

class DriverInventory {
  const DriverInventory(this.packages);
  final List<DriverPackage> packages;
  factory DriverInventory.parse(Map<String, dynamic> value) {
    if (value['source'] != 'Windows driver store' ||
        value['onlineCatalogueAvailable'] is! bool ||
        value['onlineCatalogueAvailable'] != false)
      throw const FormatException('Invalid inventory source');
    final rows = value['packages'];
    // The producer bounds its structured output to two MiB. This independent
    // record limit also bounds widget construction for an untrusted response.
    if (rows is! List || rows.length > 25000)
      throw const FormatException('Invalid package list');
    final ids = <String>{};
    String? text(Map row, String key) {
      if (!row.containsKey(key))
        throw const FormatException('Missing metadata');
      final field = row[key];
      if (field == null) return null;
      if (field is! String ||
          field.length > 4096 ||
          field.runes.any(
            (c) =>
                c < 32 ||
                c == 127 ||
                (c >= 0x202a && c <= 0x202e) ||
                (c >= 0x2066 && c <= 0x2069),
          ))
        throw const FormatException('Invalid metadata');
      return field.trim().isEmpty ? null : field;
    }

    final packages = <DriverPackage>[];
    for (final row in rows) {
      if (row is! Map) throw const FormatException('Invalid package');
      final id = row['id'];
      if (id is! String ||
          id.length > 64 ||
          !RegExp(r'^oem[0-9]+\.inf$', caseSensitive: false).hasMatch(id) ||
          id.contains('\n') ||
          !ids.add(id.toLowerCase()))
        throw const FormatException('Invalid package identity');
      packages.add(
        DriverPackage(
          id,
          text(row, 'originalName'),
          text(row, 'provider'),
          text(row, 'className'),
          text(row, 'version'),
          text(row, 'signer'),
        ),
      );
    }
    return DriverInventory(List.unmodifiable(packages));
  }
}

typedef DriverInventoryInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class DriverInventoryPage extends StatefulWidget {
  const DriverInventoryPage({super.key, required this.invoke});
  final DriverInventoryInvoke invoke;
  @override
  State<DriverInventoryPage> createState() => _DriverInventoryPageState();
}

class _DriverInventoryPageState extends State<DriverInventoryPage> {
  final scroll = ScrollController();
  final pagingFocus = FocusNode(debugLabel: 'Driver inventory paging');
  DriverInventory? inventory;
  DateTime? receivedAt;
  bool busy = false;
  String? failure;
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

  Future<void> collect() async {
    if (busy) return;
    setState(() {
      busy = true;
      inventory = null;
      receivedAt = null;
      failure = null;
    });
    try {
      final result = DriverInventory.parse(
        await widget.invoke('drivers.list', {}),
      );
      if (!mounted) return;
      setState(() {
        inventory = result;
        receivedAt = DateTime.now().toUtc();
      });
      notifyOperation(context, 'success', 'drivers.list');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => failure =
            'Driver inventory is unavailable or invalid. Collect again to retry.',
      );
      notifyOperation(context, 'error', 'drivers.list');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget detail(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiText(label),
        SelectableText(value ?? localize(context, 'Not reported')),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final rows = inventory?.packages;
    return Scaffold(
      appBar: inspectionAppBar(context, 'Driver store review'),
      body: Focus(
        focusNode: pagingFocus,
        onKeyEvent: pageKey,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            const UiText(
              'Review installed third-party driver-store packages. Collection does not install, export, update or remove drivers.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: busy ? null : collect,
                icon: const Icon(Icons.refresh),
                label: const UiText('Collect driver inventory'),
              ),
            ),
            const SizedBox(height: 16),
            OperationMotion(
              state: busy
                  ? 'working'
                  : failure != null
                  ? 'error'
                  : rows != null
                  ? 'complete'
                  : 'idle',
            ),
            if (busy) const LinearProgressIndicator(),
            if (failure != null)
              Semantics(liveRegion: true, child: UiText(failure!)),
            if (rows != null) ...[
              Text('${localize(context, 'Packages reported')}: ${rows.length}'),
              const UiText('Received at UTC'),
              SelectableText(receivedAt!.toIso8601String()),
              const UiText(
                'Receipt time is not a driver measurement or installation time. Collect again for a new inventory.',
              ),
              const UiText(
                'Signer metadata is reported by Windows. It is not an independent signature verification, compatibility check or update recommendation.',
              ),
              const UiText(
                'No online catalogue is available. Inbox drivers and device health are not covered by this inventory.',
              ),
              if (rows.isEmpty)
                const UiText(
                  'No third-party driver-store packages were reported.',
                ),
              for (final row in rows)
                Card(
                  child: ExpansionTile(
                    key: ValueKey(row.id.toLowerCase()),
                    expansionAnimationStyle:
                        MediaQuery.disableAnimationsOf(context)
                        ? const AnimationStyle(
                            duration: Duration.zero,
                            reverseDuration: Duration.zero,
                          )
                        : null,
                    title: Text(row.id),
                    subtitle: Text(
                      '${localize(context, 'Provider')}: ${row.provider ?? localize(context, 'Not reported')}',
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      detail('Published package name', row.id),
                      detail('Original file name', row.originalName),
                      detail('Provider', row.provider),
                      detail('Device class', row.className),
                      detail('Reported version', row.version),
                      detail('Reported signer', row.signer),
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
