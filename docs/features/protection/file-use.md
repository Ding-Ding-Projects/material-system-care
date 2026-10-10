# File-use inspection

Open **Tools > File use**, choose a file or enter its full local path, then select **Inspect file use**. Nothing is collected automatically. The native file picker is optional; cancelling it preserves the current path. Editing the path or starting another inspection clears old results.

The engine calls Windows Restart Manager to list affected applications and services. Each record shows its name, PID, service name when present and advisory restartable status. This workflow never requests a restart, closes a process or handle, unlocks a file or changes its contents. An empty result does not establish that the file is unlocked. Results can change immediately after collection and are not an exhaustive handle inventory.

The response echoes the exact requestedPath alongside its normalized path. The interface requires the echo to match the submitted selection before displaying results. Missing or malformed records, mismatched requests and failed refreshes do not retain older owner records. Recognized engine codes produce bounded explanations; raw exception details are not rendered.

Paths must identify an existing file through a fully qualified local filesystem path accepted by the engine. UNC paths, wildcards and alternate-stream syntax are rejected. The engine bounds the owner list to 1,024 records and retries a changing Restart Manager list at most three times, then ends the session in a finally block. This is not a guarantee that a drive-letter path resolves to physically local storage or that every operating-system call has a bounded duration.

Paths and process/service names are displayed locally. Do not publish host-specific result captures. No file content is read by this operation and no results are uploaded or automatically persisted by this workspace.

## States and verification

Official Flutter Material controls cover idle, picker, pending, result, advisory-empty and unavailable states. Working/result/error motion uses the shared motion component; result size transitions honor reduced motion. English, Cantonese and bilingual copy follow the existing scope.

Six focused widget checks cover explicit collection, request correlation, advisory emptiness, stale-result clearing, picker cancellation, Cantonese copy, pending disposal and isolated startup. The standalone invocation --file-use with exactly one --capture-frame path uses isolated default preferences and no automatic collection. Multiple workspace selectors disable capture export. Root builds and one genuine owned-fixture inspection subsequently passed as recorded below. Complete per-surface contracts remain explicitly unverified in the surface inventory.

## Built evidence

Root engine verification and desktop builds passed at 003e9cdc499956d68e9ddcba2747866e81fff070. A stale CMake cache selected a removed toolchain location; its generated directory was preserved and the exact root build succeeded after regeneration. Six File use and four process widget checks passed. A fresh isolated run produced an inspected idle frame and an actual owned-fixture query with a truthful advisory empty result. The fixture bytes remained unchanged. The result frame stays private because it contains a local path. Both owned processes and the hidden desktop were confirmed closed. The narrow verifiers checked 210 bundle files and rejected an altered capture hash before restored evidence passed. Native picker interaction, populated owner records and full appearance/input coverage remain unverified.

See [idle frame](../../captures/file-use-idle.png), [capture receipt](../../captures/file-use-idle.json) and [private-result summary](../../verification/file-use.json).
