# Cleanup and recovery presentation

## Design route and evidence boundary

Material Designer was checked before this change. The expected checkout beneath the current user's resolved Documents/GitHub directory was absent, and the available tool inventory contained no callable design creation/export/handoff capability. The existing `desktop-workspace.md` written design route is therefore used for this bounded presentation change. This document is a deterministic implementation handoff, not a captured design or runtime evidence.

Target: Flutter desktop, existing Material 3 theme. Implementation: `desktop/lib/cleanup.dart`, integrated in the existing storage workflow. No new search surface is introduced. Existing filtering retains original server indexes.

## Addressable states

| State | Required presentation and action |
| --- | --- |
| scan-empty | No eligible files, zero recorded files, no invented reclaimed space |
| scan-populated | Filename, exact byte count or unavailable, original-index checkbox, expandable full original path |
| scan-selected-subset | Only selected original server indexes are sent after explicit path review |
| apply-recorded | Recorded filename, bytes, state and localized reason; internal hashes and recovery-storage paths are omitted |
| apply-partial/cancelled | Explicit partial/stopped text, recorded item count, requested count and missing-result count when supplied |
| history-empty | No recovery receipts, without suggesting files were deleted |
| history-populated | Exact receipt identifier, recorded/moved/restored/conflict/skipped counts and contextual restoration review |
| history-unreadable | Unavailable record state, no enabled restoration action |
| restore-conflict | Localized occupied-path explanation; retained recovery data; another action rereads that exact receipt and requires confirmation |
| restore-complete | Recorded restored states; no claim about current availability beyond the response |
| invalid/failure | No unvalidated raw result rendered; localized recovery-history action instead of automatic mutation retry |

## Component and motion inventory

All controls reuse registered Flutter Material components: Card, ListTile, CheckboxListTile, ExpansionTile, OutlinedButton, Text and SelectableText. ListView and Padding supply layout; Semantics announces changed result summaries. No custom clickable container or new component registration is needed. File paths remain exact selectable text inside labelled expandable details. Summary labels and buttons use the existing English/Cantonese/bilingual localization route.

Check boxes and buttons use framework focus, keyboard, hover, press, disabled and selected states. ExpansionTile uses framework expansion motion and respects inherited reduced-motion settings. Existing request progress and cancellation remain in the workflow. No idle animation is added.

## Verification tuples

Normal viewport: 1280 × 900. Minimum: 800 × 600. Required runtime matrix: English, Cantonese and bilingual; light and dark; 100%, 125%, 150% and 200%; reduced motion on/off; every state above. Focused widget tests cover original subset indexes, exact receipt retry, excluded internal fields, empty/unknown states, and bilingual long-path content at minimum size with 200% text scaling. Text scaling is not a claim of physical display-DPI verification.

Built desktop interaction, genuine captures, and the full display-scale matrix remain separate verification work. No source test or this written reference substitutes for that evidence.
