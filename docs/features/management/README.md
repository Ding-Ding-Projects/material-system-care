# Local management

- [Process inspection](processes.md): exact-identity review and truthful graceful-close receipts.

- [Managed package discovery](managed-packages.md): explicit structured WinGet matches and contextual actions.

The management module implements installed-application inventory, WinGet operations, reversible current-user Run entries, process metadata and graceful close requests, and read-only service inventory. Registry inventory reads both uninstall views and both supported hives without executing registered command strings. AppX inventory uses the current user's supported PowerShell command.

## Requests and results

`apps.list` returns `{records, unavailable}`. Each record identifies its source and scope. Registry and AppX records have `canUninstall:false`; the UI must resolve an exact WinGet identifier separately. `apps.updates` returns `{available, exitCode, format:"wingetText", output, reason}` when WinGet exists. The command does not supply a stable JSON inventory API, so output is displayed as text and never guessed into package rows. Missing WinGet returns `available:false` and its reason.

`apps.upgrade` and `apps.uninstall` accept `{packageId:"Publisher.Package",confirmed:true}` and return `{completed,packageId,exitCode,output,restartInitiated:false}`. Only exact package identifiers and a fixed argument list are permitted. Machine-level installers may request elevation independently; this engine does not provide an elevation broker, supply credentials, consent to restart, or execute arbitrary registry uninstall commands. An absent WinGet installation returns `completed:false`.

`startup.list` returns `{records,unavailable}` for current-user Run entries. `startup.set` accepts `{id:"ExistingEntry",enabled:false,confirmed:true}`. Before deletion it writes the original name, unexpanded string, and registry kind to an exclusive journal below the engine data root. `{enabled:true}` restores that exact entry without overwriting a newer value. A retained journal after an interrupted operation requires review rather than silent replacement. Startup folders, other users, system Run entries, and scheduled tasks are outside this version.

`processes.list` returns `{records,cpuMeasurement:"cumulativeProcessorTime",stopMode:"gracefulWindowCloseOnly"}` with bytes, cumulative CPU milliseconds, exact UTC start identity and close capability. Inaccessible or exited processes return an explicit reason. `processes.stop` accepts `{pid:123,startedAt:"2026-10-09T00:00:00.0000000Z",confirmed:true}`. It validates the current SID, interactive session, start identity, and protected-process list, then requests `CloseMainWindow`. Its receipt reports `requested`, never claims termination. Applications can decline or defer the request. Forced termination is unavailable.

`services.list` returns actual service name, display name, status and start type from a fixed read-only command. `canChange:false` is deliberate. No blanket disabling or arbitrary task command is supported.

## Bounds and security

All external commands use full fixed paths, no shell, and separate `ArgumentList` values. Command output is bounded to 1 MiB per stream and three minutes per operation. Connection cancellation stops waiting and reading; a package installer already launched may continue, so cancellation does not mean rollback. Startup journals contain the registered command and remain local. Operation history excludes that command. Registry access failures and command failures must be displayed honestly. Inventory is not proof that a package is safe to remove.

## Verification

`tests/management/ManagementFixtures.cs` provides adapter fixtures and policy checks, intended for the foundation test runner. No maintenance commands were executed on the development computer. Compilation and integrated runtime evidence remain pending the root build entrypoint and foundation assembly. This module has no HTTP API, so a Postman collection is not applicable.

- [Scheduled-task review](scheduled-tasks.md): bounded, read-only task metadata and interpretation limits.

- [Service review](services.md): explicit read-only inventory, state filters and configured-start metadata.

- [Isolated capture tuples](capture-tuples.md): display-only verification controls and their limits.

- [Startup action review](startup-review.md): explicit enable/disable effects and eligible record selection.
