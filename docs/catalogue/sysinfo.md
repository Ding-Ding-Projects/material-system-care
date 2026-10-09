# IObit SysInfo

Official reference: [IObit SysInfo](https://www.iobit.com/en/system-information.php). Reviewed inventory baseline: 2026-10-08. This article records independent implementation requirements, not a claim of shipped parity.

Intended workspace: **System**. Configuration is local and operations follow the [engine protocol](../../contracts/engine-protocol.md). Each row in the [machine-readable ledger](../../contracts/capabilities.json) records API requirements, safety boundaries, implementation paths, tests and evidence. Empty proof lists mean unverified work.

| ID | Required capability | Current status | Limit or next requirement |
| --- | --- | --- | --- |
| `sysinfo.01` | Hardware inventory | unverified | Logical processor count, operating-system description, physical-memory state and drive capacities only; no complete motherboard, GPU, sensor or device inventory. |
| `sysinfo.02` | Operating system details | unverified | Operating-system description, live physical-memory usage and drive capacities; no historical telemetry, throughput or sensor dashboard. |
| `sysinfo.03` | CPU monitoring | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `sysinfo.04` | GPU monitoring | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `sysinfo.05` | Memory monitoring | unverified | Operating-system description, live physical-memory usage and drive capacities; no historical telemetry, throughput or sensor dashboard. |
| `sysinfo.06` | Disk monitoring | unverified | Operating-system description, live physical-memory usage and drive capacities; no historical telemetry, throughput or sensor dashboard. |
| `sysinfo.07` | Temperature telemetry | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `sysinfo.08` | Hardware alerts | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |
| `sysinfo.09` | System report export | unimplemented | Declared requirement only. No linked implementation and built interaction evidence has been reviewed for this row. |

## Configuration and safety

No scan grants permission to mutate the device. Mutations need the selected stable target, an explicit confirmation, cancellation where feasible, and a durable outcome record. Permissions, unsupported APIs, missing licensed engines and unavailable hardware telemetry must produce their actual reason. No advertisement, partner installation, unknown driver package or remote data upload may be silently introduced.

## Verification

Coverage structure is checked by `node tests/coverage/catalogue.test.mjs`. Passing that test proves inventory integrity only. The release completeness check is `node tests/coverage/catalogue.test.mjs --release`; it intentionally fails until every in-scope capability has linked code, focused tests and reviewed built-artifact evidence. Unit fixtures alone do not prove a visible workflow.
