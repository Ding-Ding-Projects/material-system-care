import 'package:flutter/material.dart';
import 'localization.dart';

String buildVersion(Map<String, dynamic>? ping) =>
    ping?['manifest'] is Map && ping!['manifest']['version'] is String
    ? ping['manifest']['version'] as String
    : 'build metadata unavailable';
String buildUpdatedAt(Map<String, dynamic>? ping) {
  final receipt = ping?['buildReceipt'];
  final raw = receipt is Map ? receipt['builtUtc'] : null;
  final instant = raw is String ? DateTime.tryParse(raw) : null;
  if (instant == null || !raw!.endsWith('Z')) return 'provenance unavailable';
  final time = instant.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}:${two(time.second)} ${time.timeZoneName} (UTC${time.timeZoneOffset.isNegative ? '' : '+'}${time.timeZoneOffset.inMinutes / 60})';
}

class BuildProvenance extends StatelessWidget {
  const BuildProvenance({super.key, required this.ping});
  final Map<String, dynamic>? ping;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(
            '${localize(context, 'Version')}: ${buildVersion(ping) == "build metadata unavailable" ? localize(context, "build metadata unavailable") : buildVersion(ping)}',
          ),
          Text(
            '${localize(context, 'Updated at')}: ${buildUpdatedAt(ping) == "provenance unavailable" ? localize(context, "provenance unavailable") : buildUpdatedAt(ping)}',
          ),
        ],
      ),
      const UiText(
        'Measurements below come from the local engine. No scan has permission to change files.',
      ),
    ],
  );
}
