# Desktop workspace design contract

The desktop uses Flutter 3.47.7 and genuine framework Material 3 components. Material Designer creation/export was unavailable on the implementation host: no installed executable in the inspected application locations and no callable design MCP flow. This deterministic written handoff is the fallback design record, not captured runtime evidence.

## Screen inventory

| Route | Initial state | Productive workflow |
| --- | --- | --- |
| overview | live snapshot loading | inspect measured memory, operating system and drives; request cleanup analysis |
| storage | no folder selected | choose folder; analyze actual file records; exact duplicate discovery; review recoverable cleanup and restore receipts |
| apps | inventory loading | filter installed records; inspect updates; confirm a selected upgrade or uninstall |
| startup | inventory loading | inspect entries; confirm selected state changes |
| protection | status loading | inspect security provider status and start a confirmed quick scan |
| drivers | inventory loading | inspect actual drivers and export a selected record |
| tools | idle editor | SHA-256 file hash, supported file conversion, local password generation, network diagnostics |
| activity | history loading | filter chronological engine receipts |
| settings | preference loading | theme, seed, density, language, playfulness, motion, sound and local wording preferences |
| help | offline guide | expandable local workflow and privacy guidance |

## Component registration

Every interactive visible control uses an official Flutter Material class: AppBar, NavigationRail, NavigationRailDestination, SearchBar, MenuAnchor, MenuItemButton, CheckboxMenuButton, FilledButton, OutlinedButton, TextButton, IconButton, PopupMenuButton, PopupMenuItem, TextField, DropdownButtonFormField, SegmentedButton, Slider, SwitchListTile, CheckboxListTile, AlertDialog, ExpansionTile, and ListTile. Scaffold, Material, Card, Divider, Text and SelectableText form specification-backed surfaces, typography and data presentation. Row, Column, Padding, Expanded, ListView and Scrollbar only provide supported layout internals, never custom interactive chrome. ThemeData.useMaterial3 is always true. Component provenance: https://api.flutter.dev/flutter/material/material-library.html.

## Motion and state contract

Framework controls retain official hover, focus, press and disabled state layers. Navigation transitions use AnimatedSwitcher, 250 ms, removed under OS or user reduced motion. Menus/dialogs use framework route transitions. Selection uses native selection state layers. Only active engine requests display indeterminate progress; measured progress is never invented. Success replaces the loading state with returned records. Cancellation leaves input intact. Failure renders a bounded error surface with a retry action at the originating workspace. No idle work loops exist. Sound defaults off. Additional expressive motion and native narration remain pending verification and are not claimed by this design record.

## Verification tuples

Minimum client area 800 × 600; normal 1280 × 900. Each route must be captured in English, Cantonese and bilingual; light and dark; 100%, 125%, 150% and 200%. Pending, empty, populated, selected, confirmation, unavailable and recovery states need real built captures. No capture or visual parity verdict exists in this source-only handoff.
