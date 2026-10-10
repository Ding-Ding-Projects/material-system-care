# Scheduled-task review

Open **Tools > Scheduled tasks**, select a maximum of 200, 500 or 1000 records, then choose **Read scheduled tasks**. Collection is explicit. Filter loaded records by name, folder or state; expand a record for its identity, enabled state, reported last/next run and raw last-result code.

The engine uses the supported local Get-ScheduledTask and Get-ScheduledTaskInfo cmdlets. It never runs, enables, disables, creates or deletes a scheduled task. Actions, command arguments, execution principals, credentials and task descriptions are excluded before serialization. Task names and folders can themselves be private; populated captures must remain private unless their pixels are explicitly reviewed for publication. Results are transient, are not uploaded and are not automatically added to history.

## Bounds and interpretation

The engine accepts limit from 1 through 1000, default 200. It requests one extra record to detect truncation. Enumeration order is not guaranteed; a capped result is not a stable alphabetical prefix. Visibility depends on the current account, so a non-truncated result is not a claim to see every system task. State and run information can change between reads; this is not a transactional snapshot.

Task metadata JSON is bounded to 2 MiB and depth 16. Duplicate identities, malformed fields/times, invalid result codes and contradictory unavailable-detail records are rejected. Unknown fields are discarded. Per-task run-info access failure retains the identity with unavailable timing and result fields. Sentinel dates from 1900 or earlier are represented as missing, never as proof of no execution. Reported timestamps carry no asserted timezone. Result codes may describe Task Scheduler status rather than an action failure; nonzero alone is not a diagnosis.

The query wait is twenty seconds. Cancellation, timeout or oversized output closes only the owned direct query process, with up to five additional seconds to observe exit. Unverified teardown has its own TASK_QUERY_TEARDOWN_INCOMPLETE response. Raw exception and stderr details are not displayed. A failed refresh clears previous records. No elevation is requested. Fixture contexts cannot invoke real host collection.

## Verification and remaining work

Three focused Flutter checks cover isolated startup, explicit bounded invocation, filtering, raw result-code display, failed-refresh clearing and pending disposal. Synthetic parser checks cover projection privacy, truncation, empty records, duplicates, malformed data and fixture isolation. Root engine verification and desktop builds passed at ead6535d65b92bb889936ba1f435347b2e017d9e. Three focused Flutter checks and integrated parser/privacy fixtures passed. A real hidden-desktop run completed explicit account-visible collection, expanded one record and filtered loaded rows to a no-match result. No task was run or changed. The idle frame is public; populated frames remain private because they contain local task names and identifiers. All owned bundle processes were absent and the hidden desktop closed. Evidence: docs/captures/scheduled-tasks-idle.json and docs/verification/scheduled-tasks.json. Painted-frame evidence does not establish native compositor capture or the complete appearance/accessibility matrix. Full per-surface language, search, export, accessibility, motion and appearance contracts remain separately tracked and unverified.

The isolated --scheduled-tasks entry with exactly one --capture-frame argument opens the production widget without persisted personal settings or automatic collection. It exports actual painted frames, not native compositor evidence; combining workspace selectors disables export.

## Sources

- [Microsoft Get-ScheduledTask](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/get-scheduledtask)
- [Microsoft Get-ScheduledTaskInfo](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/get-scheduledtaskinfo)
