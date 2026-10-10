import 'package:flutter/material.dart';

/// A Material label above its control keeps bilingual and enlarged text out of
/// single-line hint and floating-label slots. The control owns focus and input.
class LabeledControl extends StatelessWidget {
  const LabeledControl({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
        softWrap: true,
      ),
      const SizedBox(height: 8),
      Semantics(label: label, child: child),
    ],
  );
}

/// Uses the official Material search control and its existing state animation.
class LabeledSearchBar extends StatelessWidget {
  const LabeledSearchBar({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.leading,
    this.trailing,
  });
  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? leading;
  final Iterable<Widget>? trailing;

  @override
  Widget build(BuildContext context) => LabeledControl(
    label: label,
    child: SearchBar(
      controller: controller,
      onChanged: onChanged,
      leading: leading,
      trailing: trailing,
    ),
  );
}
