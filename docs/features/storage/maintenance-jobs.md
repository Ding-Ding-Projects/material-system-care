# Durable selected-folder analysis

Read-only storage analysis and exact duplicate inspection can run as durable local jobs. Direct storage requests remain available. Detached jobs never grant consent to change files.

## API and limits

`jobs.start` accepts `{method, parameters}`. The only allowed methods are `storage.analyze` and `storage.duplicates`. Parameters contain a selected existing `path`, optional integer `maxEntries` and, for duplicates only, optional integer `maxHashMiB`. Unknown and duplicate fields are rejected. The engine validates the directory and reparse-point ancestors, then retains its absolute path. Admission permits four active jobs and 1000 retained receipts.

`jobs.status` and `jobs.cancel` accept a 32-hex `jobId`. `jobs.list` accepts optional integer `limit` from 1 through 100, default 50. Listing returns newest receipts without results or selected paths. Individual status returns selected parameters and measured results. Receipts remain local in SQLite and never enter general history or a provider request.

Records include `jobId`, `method`, `state`, UTC `createdAt` and `updatedAt`, `cancellationRequested`, nullable `result`, nullable safe `error`, nullable `parameters` and `mutationPerformed:false`. States are `queued`, `running`, `succeeded`, `failed`, `cancelled` and `interrupted`. A succeeded result may still contain the scan's inaccessible count, depth limit, truncation or hash budget. The interface must retain those measured limitations.

## Cancellation and restart

Admission persists a queued receipt before returning identity. Disconnect does not cancel detached analysis. Reconnect uses the same identity without automatic replay. Cancellation persists the request before signalling the worker. Only observed worker cancellation produces `cancelled`. Success may win the race and remains successful; cancelling a terminal receipt is idempotent.

One engine holds an exclusive store lease. Another receives `JOBS_IN_USE`. Failed acquisition is not cached: the same engine context can retry after the competing owner releases its lease. Initialization is synchronized and publishes only a successfully acquired manager. A disposed context cannot reacquire a lease. On reacquiring the lease after restart, the engine marks unfinished rows `interrupted` with `ENGINE_INTERRUPTED`. It never replays them. Completed receipts survive restart. Review the target and explicitly start new analysis after interruption.

SQLite FULL synchronous writes retain admission and transition receipts. Terminal write failure leaves the prior active state for later interruption recovery rather than claiming persisted success. Results are bounded to 3 MiB and responses to 4 MiB. The store stops admission at 1000 rows and retains old receipts; retention management is not implemented.

## Safety and verification

Cleanup, package changes, startup changes, process termination, arbitrary commands and host power actions cannot detach through this API. Existing cleanup selected-target review and recovery remain separate. Paths and file information are local private data and must not appear in telemetry, public captures or exported diagnostics.

`tests/engine-core/MaintenanceJobFixtures.cs` uses disposable folders to verify real measurements, exact duplicate groups, bounded validation, unsupported-method rejection, duplicate-field rejection, cancellation at an internal deterministic pre-execution seam, a separate success-before-cancellation case, terminal idempotence, exclusive ownership, concurrent same-context initialization after repeated transient lease rejection, disposal, completion persistence and interrupted recovery without replay. The internal seam is accessible only to the fixture assembly and is never supplied through IPC. These are backend fixtures, not desktop interaction, installer acceptance or complete capability parity.
