import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inspection_app_bar.dart';
import 'localization.dart';
import 'motion.dart';
import 'notifications.dart';

const defenderBooleanLabels = <String, String>{
  'AMServiceEnabled': 'Antimalware service',
  'AntivirusEnabled': 'Antivirus',
  'AntispywareEnabled': 'Antispyware',
  'RealTimeProtectionEnabled': 'Real-time protection',
  'BehaviorMonitorEnabled': 'Behavior monitoring',
  'IoavProtectionEnabled': 'Downloaded-file protection',
  'NISEnabled': 'Network inspection',
  'RebootRequired': 'Restart required (reported)',
};
const defenderDateLabels = <String, String>{
  'AntivirusSignatureLastUpdated': 'Signature updated at UTC',
  'QuickScanStartTime': 'Last quick scan started at UTC',
  'QuickScanEndTime': 'Last quick scan ended at UTC',
  'FullScanStartTime': 'Last full scan started at UTC',
  'FullScanEndTime': 'Last full scan ended at UTC',
};

/// Windows PowerShell 5.1 uses the JSON.NET date form. Milliseconds identify
/// the UTC instant; an optional suffix describes the original local offset.
DateTime? parseProtectionDate(Object? value) {
  if (value == null) return null;
  if (value is! String || value.length > 40)
    throw const FormatException('Invalid provider date');
  final match = RegExp(
    r'^/Date\((-?\d{1,15})([+-]\d{4})?\)/$',
  ).firstMatch(value);
  if (match == null || match.end != value.length)
    throw const FormatException('Invalid provider date');
  final offset = match[2];
  if (offset != null) {
    final hours = int.parse(offset.substring(1, 3)),
        minutes = int.parse(offset.substring(3));
    if (hours > 14 || minutes > 59 || (hours == 14 && minutes != 0))
      throw const FormatException('Invalid provider offset');
  }
  final milliseconds = int.parse(match[1]!);
  if (milliseconds < -62135596800000 || milliseconds > 253402300799999)
    throw const FormatException('Provider date outside range');
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

class DefenderStatus {
  const DefenderStatus(this.flags, this.signatureVersion, this.dates);
  final Map<String, bool?> flags;
  final String? signatureVersion;
  final Map<String, DateTime?> dates;
}

class FirewallProfileStatus {
  const FirewallProfileStatus(
    this.name,
    this.enabled,
    this.inbound,
    this.outbound,
  );
  final String name;
  final int enabled, inbound, outbound;
}

class ProtectionStatus {
  const ProtectionStatus(
    this.defender,
    this.defenderReason,
    this.firewall,
    this.firewallReason,
  );
  final DefenderStatus? defender;
  final String? defenderReason, firewallReason;
  final List<FirewallProfileStatus>? firewall;
  factory ProtectionStatus.parse(Map<String, dynamic> value) {
    for (final key in [
      'defender',
      'defenderUnavailableReason',
      'firewall',
      'firewallUnavailableReason',
    ]) {
      if (!value.containsKey(key))
        throw const FormatException('Missing protection source');
    }
    DefenderStatus? defender;
    final rawDefender = value['defender'];
    final defenderReason = value['defenderUnavailableReason'];
    if (rawDefender == null) {
      if (defenderReason !=
          'Defender status is unavailable on this installation or for this account.')
        throw const FormatException('Invalid Defender availability');
    } else {
      if (rawDefender is! Map || defenderReason != null)
        throw const FormatException('Contradictory Defender source');
      final flags = <String, bool?>{};
      for (final key in defenderBooleanLabels.keys) {
        if (!rawDefender.containsKey(key) ||
            (rawDefender[key] != null && rawDefender[key] is! bool))
          throw const FormatException('Invalid Defender flag');
        flags[key] = rawDefender[key] as bool?;
      }
      final version = rawDefender['AntivirusSignatureVersion'];
      if (!rawDefender.containsKey('AntivirusSignatureVersion') ||
          (version != null &&
              (version is! String ||
                  version.length > 128 ||
                  version.runes.any((c) => c < 32 || c == 127))))
        throw const FormatException('Invalid signature');
      final dates = <String, DateTime?>{};
      for (final key in defenderDateLabels.keys) {
        if (!rawDefender.containsKey(key))
          throw const FormatException('Missing Defender date');
        dates[key] = parseProtectionDate(rawDefender[key]);
      }
      defender = DefenderStatus(
        Map.unmodifiable(flags),
        version == '' ? null : version as String?,
        Map.unmodifiable(dates),
      );
    }
    final rawFirewall = value['firewall'];
    final firewallReason = value['firewallUnavailableReason'];
    List<FirewallProfileStatus>? firewall;
    if (rawFirewall == null) {
      if (firewallReason != 'Firewall status is unavailable for this account.')
        throw const FormatException('Invalid firewall availability');
    } else {
      if (rawFirewall is! List ||
          rawFirewall.length != 3 ||
          firewallReason != null)
        throw const FormatException('Invalid firewall source');
      final names = <String>{};
      firewall = <FirewallProfileStatus>[];
      for (final row in rawFirewall) {
        if (row is! Map ||
            !{'Domain', 'Private', 'Public'}.contains(row['Name']) ||
            !names.add(row['Name'] as String) ||
            row['Enabled'] is! int ||
            !{0, 1, 2}.contains(row['Enabled']) ||
            row['DefaultInboundAction'] is! int ||
            !{0, 2, 4}.contains(row['DefaultInboundAction']) ||
            row['DefaultOutboundAction'] is! int ||
            !{0, 2, 4}.contains(row['DefaultOutboundAction']))
          throw const FormatException('Invalid firewall profile');
        firewall.add(
          FirewallProfileStatus(
            row['Name'] as String,
            row['Enabled'] as int,
            row['DefaultInboundAction'] as int,
            row['DefaultOutboundAction'] as int,
          ),
        );
      }
      firewall = List.unmodifiable(firewall);
    }
    return ProtectionStatus(
      defender,
      defenderReason as String?,
      firewall,
      firewallReason as String?,
    );
  }
}

typedef ProtectionStatusInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class ProtectionStatusPage extends StatefulWidget {
  const ProtectionStatusPage({super.key, required this.invoke});
  final ProtectionStatusInvoke invoke;
  @override
  State<ProtectionStatusPage> createState() => _ProtectionStatusPageState();
}

class _ProtectionStatusPageState extends State<ProtectionStatusPage> {
  final scroll = ScrollController();
  final pagingFocus = FocusNode(debugLabel: 'Protection status paging');
  bool busy = false;
  ProtectionStatus? status;
  DateTime? receivedAt;
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

  Future<void> refresh() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = null;
      receivedAt = null;
      failure = null;
    });
    try {
      final parsed = ProtectionStatus.parse(
        await widget.invoke('security.status', {}),
      );
      if (!mounted) return;
      setState(() {
        status = parsed;
        receivedAt = DateTime.now().toUtc();
      });
      notifyOperation(context, 'success', 'security.status');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => failure =
            'Protection status is unavailable or invalid. Refresh to try again.',
      );
      notifyOperation(context, 'error', 'security.status');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

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
  Widget row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text('${localize(context, label)}: ${localize(context, value)}'),
  );
  @override
  Widget build(BuildContext context) {
    final data = status;
    return Scaffold(
      appBar: inspectionAppBar(context, 'Protection status'),
      body: Focus(
        focusNode: pagingFocus,
        onKeyEvent: pageKey,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          children: [
            const UiText(
              'Read Microsoft Defender and firewall status without changing settings or starting scans.',
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh),
                label: const UiText('Refresh protection status'),
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
              panel('Status interpretation', [
                const UiText('Received at UTC'),
                SelectableText(receivedAt!.toIso8601String()),
                const UiText(
                  'Receipt time is not a provider measurement time. Provider dates may be cached.',
                ),
                const UiText(
                  'These settings do not establish that the machine is healthy or threat-free. No scan or configuration change was requested.',
                ),
              ]),
              panel(
                'Microsoft Defender status',
                data.defender == null
                    ? [UiText(data.defenderReason!)]
                    : [
                        for (final flag in data.defender!.flags.entries)
                          row(
                            defenderBooleanLabels[flag.key]!,
                            flag.value == null
                                ? 'Not reported'
                                : flag.value!
                                ? 'Yes'
                                : 'No',
                          ),
                        const SizedBox(height: 8),
                        const UiText('Antivirus signature version'),
                        SelectableText(
                          data.defender!.signatureVersion ??
                              localize(context, 'Not reported'),
                        ),
                        for (final date in data.defender!.dates.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UiText(defenderDateLabels[date.key]!),
                                SelectableText(
                                  date.value?.toIso8601String() ??
                                      localize(context, 'Not reported'),
                                ),
                              ],
                            ),
                          ),
                      ],
              ),
              const SizedBox(height: 16),
              UiText(
                'Firewall profiles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const UiText(
                'Profile settings alone do not establish effective network filtering.',
              ),
              if (data.firewall == null)
                panel('Firewall unavailable', [UiText(data.firewallReason!)])
              else
                for (final profile in data.firewall!)
                  Card(
                    child: ExpansionTile(
                      expansionAnimationStyle:
                          MediaQuery.disableAnimationsOf(context)
                          ? const AnimationStyle(
                              duration: Duration.zero,
                              reverseDuration: Duration.zero,
                            )
                          : null,
                      title: UiText('${profile.name} firewall profile'),
                      subtitle: UiText(
                        profile.enabled == 2
                            ? 'Not configured'
                            : profile.enabled == 1
                            ? 'Enabled'
                            : 'Disabled',
                      ),
                      childrenPadding: const EdgeInsets.all(16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        row(
                          'Default inbound action',
                          profile.inbound == 0
                              ? 'Not configured'
                              : profile.inbound == 2
                              ? 'Allow'
                              : 'Block',
                        ),
                        row(
                          'Default outbound action',
                          profile.outbound == 0
                              ? 'Not configured'
                              : profile.outbound == 2
                              ? 'Allow'
                              : 'Block',
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
