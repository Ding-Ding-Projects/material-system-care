# Source mapping and fixture evidence

## Reviewed source baseline

The catalogue now links 44 independently implemented subsets to engine source at `f890a84ae27a97628fe001fa69d34ed47af0563a` and desktop source at `d8280ec6bfd1396b3f1f90ed73b2c6cf7be9359e`. Each mapped row retains the original reference capability and scope, exact method, source/test paths, source revisions, coverage level and remaining gap. All 44 have status **unverified**. There are 234 unimplemented, three unavailable-engine and 14 explicitly excluded rows; none is verified.

A method's existence proves source availability only. A fixture proves only its actual assertions. A desktop control proves neither a successful live operation nor reference-product parity. The capability and universal release gates remain red. Current audit work on response bounds and the native request deadline also means the assembled runtime has no final release verdict.

## Engine build receipt

The integration owner reported `build.bat /s --target=engine --verify-engine` exited 0. The documentation lane independently read its generated build receipt and observed:

- Source commit: `7e2a8c88d59d2cf5f6e5ba53615aa8fcaafd0653`.
- Engine executable SHA-256: `282a9a22b3641328b52a27985f74ad562208ff70b5a4dd8d7ef975c176c31cda`.
- Manifest SHA-256: `327304f034938c77e6962c4aef81ea98502c68333792049f962a2b8c04aff57b`.
- Receipt build time: `2026-10-09T01:20:09.7271817Z`.

The receipt belongs to that exact engine source, not to later changes or the desktop package. The documentation lane did not independently rerun engine or Flutter fixtures and has no retained raw fixture execution log. The counts below are owner-reported execution results cross-checked against the referenced fixture source. This summary is not a built-surface evidence receipt.

## Fixture scopes

| Fixture | Reported result | What the assertions cover | What they do not prove |
| --- | --- | --- | --- |
| `tests/engine-core/Program.cs` | 15 assertions/groups | Fixture cannot elevate; management policy/consent checks; driver XML parsing; explicit consent/elevation refusal; request version and transport bounds | Live scans, driver installation, application installation or desktop interaction |
| `tests/utilities/Program.cs` | Seven groups | File hash shape, JSON round trip, no overwrite, invalid JSON rejection, random generation contract, eDPI arithmetic, provider default disabled | Complete converter formats, AI/media inference, provider invocation, desktop privacy flow or screenshot safety |
| `tests/storage/Program.cs` | 14 checks | Selected-folder totals, empty directories, exact duplicate grouping, bounds, consent, cleanup scope, changed-file rejection, recovery conflict and retry, replay behavior, recovery history and cancellation | Whole-drive cleanup, arbitrary document deletion, sector recovery, defragmentation or every race condition |
| `tests/protection/Program.cs` | 19 assertions | Structured driver XML, malformed XML/DTD rejection, supported method registration, literal consent and elevation refusal | Real Defender scanning, antivirus efficacy, driver export/install success, restore or proprietary-engine parity |
| `tests/engine-core/verify.ps1` | Eight groups | Protocol, settings persistence, history, sensitive-setting rejection, version/unknown method rejection, live snapshot fields and named-pipe source binding | Per-surface universal features, full native bridge timing, desktop interaction or installation |

The storage symbolic-link fixture was skipped with `ERROR_PRIVILEGE_NOT_HELD (1314)`. Reparse-path behavior therefore lacks that runtime proof on this host; a source check or skipped branch cannot turn it green. No host privilege was changed to make the fixture pass.

## Desktop test scope

`desktop/test/workspace_test.dart` supplies a mocked MethodChannel that throws `MissingPluginException`. It checks productive navigation, the disconnected/provenance-unavailable state, search and the Tools editor. It cannot prove a live named-pipe operation, successful mutation, persistence across real process restarts or real build provenance.

`desktop/test/component_registry_test.dart` accepts registered component names and rejects a generic replacement name. It does not inspect every rendered control. Neither file supplies genuine desktop capture evidence. No execution result for these Flutter tests is newly claimed by this documentation lane.

## Important remaining gaps

The driver engine enumerates installed packages and accepts an explicitly selected signed local INF, but has no newer-driver catalogue. Driver export fixtures stop at consent/elevation checks; there is no verified backup/restore round trip. Apps inventory returns registry and AppX records whose IDs are not WinGet package IDs. Update discovery retains text rather than inventing normalized package records; the desktop therefore cannot assume those records enable upgrade/uninstall.

Only current-user HKCU Run strings are editable. Service data is read-only. Process close is a same-user interactive close request, never forced termination or proof of resource optimization. Memory counts do not implement a recommendation engine, and file totals do not implement a disk map; those two requirements remain unimplemented.

Protection is a supported Microsoft Defender and firewall integration. It does not bundle or reproduce IObit/Bitdefender engines. Recovery means temporary-file quarantine restoration, not deleted-sector recovery. File conversion currently covers text encodings and JSON formatting, not universal documents/media. The local Ollama adapter offers opt-in model listing and chat, not full model-suite lifecycle management. eDPI arithmetic is in the engine but has no desktop calculator control. A power-supply headroom formula is deliberately not credited as the full catalogue calculator.
