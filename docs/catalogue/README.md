# Capability catalogue

This is a fixed, versioned inventory for an independent Windows 11 x64 suite. It does not import vendor code, engines, databases, trademarks, subscription entitlements or performance claims. Free and Pro reference editions are mapped into one independent capability set. A catalogue definition, disabled control, route, operating-system settings link or inventory record does not establish functional parity.

Baseline `2026-10-08.1` contains **295 capability rows**, including exactly 24 Advanced SystemCare toolbox entries and 26 online tools. Review the [ledger](../../contracts/capabilities.json) for individual safety and platform needs.

## Families

- [Advanced SystemCare Free / Pro](asc-care.md)
- [Advanced SystemCare Free / Pro](asc-speed.md)
- [Advanced SystemCare Free / Pro](asc-protect.md)
- [Advanced SystemCare toolbox](asc-toolbox.md)
- [Advanced SystemCare Ultimate](ultimate.md)
- [Driver Booster Free / Pro](drivers.md)
- [IObit Malware Fighter Free / Pro](malware.md)
- [IObit Uninstaller Free / Pro](uninstaller.md)
- [IObit Software Updater](updater.md)
- [IObit SysInfo](sysinfo.md)
- [Protected Folder](folder.md)
- [Smart Defrag](defrag.md)
- [IObit Undelete](undelete.md)
- [IObit Unlocker](unlocker.md)
- [Random Password Generator](password.md)
- [Start Menu 8](start.md)
- [WinMetro](metro.md)
- [MacBooster capability adaptations](mac-adapted.md)
- [AMC Security capability adaptations](amc-adapted.md)
- [IObit online tools](online.md)

## Status semantics

- `unimplemented`: required behavior lacks reviewed implementation and proof.
- `unverified`: a linked independent implementation subset exists, but built interaction, captures or full required behavior remains incomplete.
- `unavailable`: a necessary engine, API or provider is absent. It remains a gap.
- `excluded`: named behavior is beyond the explicit release boundary, with the reason retained.
- `verified`: allowed only with exact implementation, test and built evidence references. No row in this baseline is verified. [Source mapping and fixture scope](../architecture/fixture-evidence.md) distinguish implemented subsets from reference parity.

## Ownership and historical boundaries

The [partner and historical appendix](partner-historical.md) is separate from IObit product ownership. The [architecture limitations](../architecture/capability-boundaries.md) explain why security monitoring, vault enforcement, boot-time defragmentation, hardware estimates, encrypted PDF operations and deleted-file recovery need more than ordinary interface controls.
