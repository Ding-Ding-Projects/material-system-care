# MacBooster capability adaptations

Official reference: [MacBooster capability adaptations](https://www.macbooster.net/). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **Storage**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `mac-adapted.01` | System junk review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.02` | Threat scan handoff | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.03` | Large file review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.04` | Duplicate finder | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.05` | Startup review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.06` | Application uninstall | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.07` | Memory pressure review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.08` | Photo duplicate review | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |
| `mac-adapted.09` | Disk usage map | unimplemented | Only the useful Windows 11 behavior is in scope. No macOS, Android, companion application or cross-device administration is planned. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
