# MacBooster capability adaptations

Official reference: [MacBooster capability adaptations](https://www.macbooster.net/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Storage**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `mac-adapted.01` | System junk review | unverified | Only aged current-user temporary files in a server-issued recoverable plan; no browser privacy sweep, system-wide disk cleaner or all-user cleanup. |
| `mac-adapted.02` | Threat scan handoff | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.03` | Large file review | unverified | Largest 100 files within a bounded selected-root scan; no deletion or complete all-drive inventory. |
| `mac-adapted.04` | Duplicate finder | unverified | Bounded selected-folder SHA-256 plus byte-comparison groups; read-only, no automatic duplicate deletion. |
| `mac-adapted.05` | Startup review | unverified | Current-user HKCU Run string entries only, with original-state journal; no machine entries, startup-folder mutation or scheduler management. |
| `mac-adapted.06` | Application uninstall | unverified | Exact WinGet ID only with consent; no automatic mapping from registry/AppX records, leftover cleanup or full Uninstaller parity. |
| `mac-adapted.07` | Memory pressure review | unverified | Process working-set and cumulative CPU records plus same-user interactive graceful-close request. No forced termination, RAM recycling, service mutation or boost guarantee. |
| `mac-adapted.08` | Photo duplicate review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.09` | Disk usage map | unimplemented | Supporting process or storage measurements do not implement memory recommendations or a visual disk map. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
