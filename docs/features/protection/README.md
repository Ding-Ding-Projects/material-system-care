# Protection and local diagnostics

`ProtectionModule` implements the engine methods below. Platform availability and elevation are checked at execution time. Disabled or missing platform components are reported honestly rather than replaced by simulated results.

| Method | Parameters | Behavior |
| --- | --- | --- |
| `security.status` | `{}` | Reads Defender and firewall profile status through a fixed PowerShell script. Each unavailable subsystem has an explicit reason. |
| `security.scan` | `{"kind":"quick","confirmed":true}` | Runs Defender quick or full scan through `MpCmdRun.exe`. Requires elevation. Records start and completion separately. |
| `drivers.list` | `{}` | Parses PnPUtil XML inventory of third-party packages in the local driver store. No proprietary online catalogue is provided. |
| `drivers.export` | `{"id":"oem42.inf","destination":"D:\\Backups","confirmed":true}` | Revalidates a published package identifier and exports it into a newly created backup directory. `id: "all"` exports all third-party packages. Requires elevation. |
| `drivers.install` | `{"path":"D:\\Package\\device.inf","confirmed":true}` | Requires a local existing INF, SetupAPI signature verification for the current platform, and elevation. PnPUtil controls applicability and ranking. Never forces a lower-ranked driver or requests a restart. |
| `network.diagnostics` | `{"host":"example.com"}` or `{}` | Lists local interfaces. An optional single hostname/IP receives bounded DNS resolution and one ICMP echo. No subnet scan, port scan, or credentials. |
| `files.lockOwners` | `{"path":"D:\\Data\\example.txt"}` | Queries Restart Manager for affected applications without closing a handle or process. Results are advisory, not an exhaustive handle inventory. |

## Safety and failure modes

Mutation methods require literal JSON boolean `confirmed: true`. Analysis does not grant consent. Elevation is never attempted automatically; an approved elevated engine is required. Driver paths reject network paths, device namespace paths, wildcards, alternate streams and reparse-point ancestors. Exports use new child directories and preserve partial output when interrupted. Driver packages must remain available while Windows validates and stages them. Windows performs its own package integrity checks; a successful tool exit does not prove a device changed drivers.

External tools use fixed executable locations and `ProcessStartInfo.ArgumentList`, with no shell execution. Security status uses only constant PowerShell source. Tool output is bounded to 2 MiB per stream. Inventory and status operations have short deadlines; driver operations have five minutes, and scans have one hour. Cancellation stops the owned command process, but a platform service may continue work already submitted. Cancellation or timeout never becomes a completion receipt. No raw tool output or detection paths enter history.

SetupAPI verification deliberately accepts only a successful `SetupVerifyInfFile` result. Authenticode-only packages returning special trust-status error codes are conservatively rejected. Missing structured inventory support returns an explicit capability error rather than parsing localized console text. Network diagnostic failures distinguish DNS, ICMP and deadline errors. ICMP filtering alone does not prove connectivity failure.

## Verification status

The read-only inventory schema was inspected on the development host, confirming `pnputil/driver` records with a `DriverName` attribute. Fixture coverage exercises that schema, malformed XML, external-entity rejection, confirmation and elevation boundaries. Active antivirus scans, driver export and driver installation were not run on the user's host. Hardware/device applicability, signature acceptance and mutation receipts require a disposable Windows verification environment before release claims.

## Platform references

- [Microsoft driver inventory guidance](https://learn.microsoft.com/en-us/windows-hardware/drivers/driversecurity/create-a-driver-inventory)
- [PnPUtil command syntax](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax)
- [SetupAPI signature verification](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/using-setupapi-to-verify-driver-authenticode-signatures)
- [Defender command line](https://learn.microsoft.com/en-us/defender-endpoint/command-line-arguments-microsoft-defender-antivirus)

These local IPC methods do not expose an HTTP API. A Postman collection is not applicable.

- [File-use inspection](file-use.md): explicit read-only Restart Manager workspace and advisory results.
