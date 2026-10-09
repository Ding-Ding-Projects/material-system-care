# Capability and platform boundaries

## Independent scope

The product targets Windows 11 x64 only. References to macOS and Android identify useful behaviors adapted to Windows; they do not create companion products, Android package tooling, cross-device administration or a macOS runtime. IObit product names identify comparison sources. No source code, licensed engine, cloud database, benchmark corpus or subscription entitlement is supplied by naming the product.

The [capability ledger](../../contracts/capabilities.json) preserves every declared row, including unavailable engines and explicit exclusions. The [catalogue](../catalogue/README.md) is an explanation of scope, not an operational command catalogue or a replacement for task workspaces.

## Security engines

Microsoft Defender status, definition freshness and an explicitly requested supported scan are possible Windows integrations. They cannot prove independent IObit, Bitdefender, ransomware, boot-record, browser-password, network interception or file-execution detection parity. Those behaviors need a licensed or independently implemented engine, safe update distribution, malware test samples, false-positive handling and verified enforcement. Polling Windows Security is not an antivirus engine.

Browser filtering, fingerprint protection and webmail warnings need a separately permissioned browser extension and maintained rules. Editing browser files or reading saved credentials is outside the safety boundary. A settings link may provide a useful supported handoff, but its status must remain a handoff rather than protection provided by this product.

## Storage and recovery

Cleanup requires server-issued plans with revalidated roots, file identity, size and modification state. The approved plan moves eligible files to recoverable storage. Exclude system-critical paths, reparse-point escapes, alternate-volume destinations, user documents and another user's data. A duplicate candidate requires content hashes and a byte comparison before a destructive action; matching names and sizes alone cannot prove equality.

Windows disk optimization APIs and supported operating-system tools may provide analysis, HDD optimization and SSD trim with explicit elevation. The suite does not install a boot-time driver or promise vendor-specific layout algorithms. MFT, active registry, paging and hibernation defragmentation are explicitly outside this release. SSD erasure guarantees are invalid in the presence of wear levelling, TRIM, journaling, snapshots and remapped sectors.

Deleted-file recovery needs a real read-only source-media scanner and a different selected destination volume. Recycle Bin restoration is useful but cannot prove recovery after the bin was emptied. TRIM, overwrites and encryption can prevent recovery. Recoverability must be measured or unknown, never a fabricated percentage.

## System and application changes

Driver discovery uses SetupAPI, Configuration Manager and supported inventory. Installation requires trusted signed packages, explicit targets, elevation, backup and an actual receipt. An OEM catalogue or licensed update provider is required to claim a newer compatible driver exists. A device inventory alone cannot prove updater parity.

Application update and removal operations must use fixed executable names and structured argument lists, trusted package identifiers, verified installers and explicit consent. No arbitrary shell execution is exposed. Install monitoring and relocation require a real change journal and rollback model; a before/after installed-program list is insufficient. Registry deletion is never a generic repair step. Legacy shell injection and unsupported Windows 8/10 customizations are not Windows 11 parity.

## Privacy, telemetry and providers

A protected folder needs an authenticated encrypted vault and a disclosed recovery model. Hidden attributes and ACL changes are not equivalent to encryption or kernel enforcement, and administrators remain outside ordinary ACL isolation. Passwords use a cryptographic random source, stay local and never enter general logs or history.

Hardware temperatures and SMART information are often unavailable through supported user-mode interfaces. Show unavailable with the real reason. CPU/GPU estimates, game requirements, FPS, ratings and power-supply estimates require a versioned licensed dataset and explicit uncertainty. A synthetic formula is not measured benchmark data.

Email breach lookup, AI editing, enhancement, math, background removal, weather, news and speed testing need configured providers or local engines. Disclose provider, data sent, cost and retention before opt-in. A provider card is not an implemented operation. Camera and microphone tests require explicit visible permission and no default recording. PDF restriction removal requires a user-supplied valid password and authorized document; no cracking or access-control circumvention is implemented.

## Power and remote-device boundary

No workflow automatically shuts down, restarts, signs out, sleeps or hibernates the local host. Show a manual operating-system handoff when appropriate. No forced process termination, kernel driver, remote-device wipe, phone call/SMS filtering or Android package administration belongs to this release.
