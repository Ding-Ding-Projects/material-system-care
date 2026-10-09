# Blue-screen investigation

Open **Tools → Blue-screen diagnostics**. Choose a lookback period, then select **Read crash evidence**. Collection is explicit and read-only. The separate stop-code field accepts hexadecimal (`0x0000009F`) or unsigned decimal (`159`) without collecting host events.

## Evidence and interpretation

The engine queries the Windows System event log through the supported `wevtutil.exe` utility. It selects only provider-qualified event 1001 (`Microsoft-Windows-WER-SystemErrorReporting`) and event 41 (`Microsoft-Windows-Kernel-Power`). A nonzero event 41 BugcheckCode is decimal. WER report codes are parsed as bounded leading hexadecimal values.

An unexpected restart alone does not establish that a blue screen occurred. Zero or unreadable codes remain explicitly uncertain. Matching timestamps are not deduplicated: separate event record identifiers remain available. Recorded event times may follow a crash or restart and are not presented as exact crash times.

Nine common stop codes have curated names and broad categories. Other values remain uncatalogued. Neither the code nor its category establishes a root cause or identifies a culprit driver. Next checks describe comparing recent changes, preserving evidence, and using Microsoft WinDbg with matching symbols when deeper analysis is appropriate.

## Limits and privacy

Collection accepts `days` from 1 through 365 and `limit` from 1 through 100; the interface requests at most 50 events. The query has a 15-second deadline and a 2 MiB output bound. A maximum of 100 dump-file metadata records are returned from the standard Windows dump locations. Reparse-point dump directories and files are excluded.

The engine reads dump names, lengths and modification times, never dump contents, stacks or symbols. It excludes raw event messages, computer names, SIDs, bugcheck address parameters and full file paths. Responses are transient, are not automatically recorded in operation history, and are not uploaded. No debugger, driver, privilege, event-log configuration, restart, repair or crash-trigger action is performed. Fixture contexts cannot inspect actual host events.

An inaccessible event query returns `EVENT_LOG_UNAVAILABLE`, not an empty successful report. Invalid limits or codes return `INVALID_PARAMETERS`. Malformed XML and entity declarations are rejected. Metadata access limitations are warnings. A failed refresh clears the previous report so old evidence cannot masquerade as a new result.

## Verification

The standalone fixture project checks decimal/hex parsing, provider qualification, unknown codes, zero-code semantics, timestamp and record retention, malformed and entity XML, output bounds, cancellation, privacy projection and fixture isolation. The widget fixtures check explicit collection, request parameters, stale-result removal and disposal during a pending request. Run the engine fixtures with the root `build.bat /s --target=engine --verify-engine`; focused Flutter fixtures are in `desktop/test/crash_diagnostics_test.dart`.

Built runtime interaction, the complete appearance/accessibility matrix, and screenshots remain separate delivery gates. Fixture success does not establish those results.

## Sources

- [Microsoft: troubleshoot unexpected reboots using event logs](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-unexpected-reboots-system-event-logs)
- [Microsoft: interpret Kernel-Power event 41](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/event-id-41-restart)
- [Microsoft: bug-check code reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/bug-check-code-reference2)
