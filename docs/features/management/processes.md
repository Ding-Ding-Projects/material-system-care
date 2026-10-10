# Process inspection and graceful close

Open **Tools → Processes**, then refresh explicitly. The workspace displays process names and identifiers, UTC start identities, working-set bytes and cumulative CPU milliseconds. CPU time is not an instantaneous utilization percentage. Search filters name and PID; inaccessible records retain their reason. No collection starts just by opening the page.

A close action is enabled only for a record that advertises the capability and carries a valid PID and start identity. Review the exact name, PID and start identity and save work before confirming. The engine rechecks the current identity, owner, interactive session and protected-process list before requesting CloseMainWindow. There is no forced termination. An application can decline or show an unsaved-work prompt.

The receipt distinguishes an accepted request from a declined request; neither proves exit. After an attempted request or an unavailable outcome, records are cleared and another mutation requires a fresh inventory. Cancelling review sends nothing. A failed inventory refresh clears stale rows. Process records are transient and are not exported or uploaded by this page. Existing engine history records the requested PID and outcome.

Official Material controls provide focus, hover and press states; operation transitions use the shared reduced-motion-aware component. Review does not display an execution spinner. English and Cantonese copy is registered and the route inherits current language and motion preferences.

Three focused Flutter fixtures verify explicit collection, protected-row disabling, review cancellation, exact PID/start identity, accepted and declined receipts, and removal of stale actionable rows. No real process close was performed. Native build, real interaction capture and universal per-surface contracts remain unverified until separately evidenced.

The root desktop and website builds passed at 48e92f927d338e45c7f913107daea145f15546ae. The first desktop attempt failed without detailed output; the single verbose retry succeeded without source changes, so the initial cause remains unestablished. Real process-workspace interaction and capture remain pending.

## Isolated frame evidence

Launch with `--processes --capture-frame=<absolute-new-png>` to export the actual painted workspace with isolated default preferences. Do not combine `--processes` with `--diagnostics`; that combination disables isolated export. Capture starts no host collection, injects no records and performs no close action.

The process workspace now has an inspected source-bound painted frame at docs/captures/processes-idle.png, SHA-256 2c87439a9470e527a740898f57ed8a9838a82cf1b0d0b8635454472b8a880c18, 1264 by 681. Producer a9975e2d639f0fe37b4fc3c699ad05f9df2a2aee passed the root desktop build. Lowlevel launched the real workspace with isolated defaults; no process collection, injected data or close action occurred. Both desktop and engine executable paths were confirmed absent and the named desktop closed. The validator checked all 210 bundle files and rejected an altered PNG hash before passing restored evidence. This is render-only proof, not native-compositor or interaction proof. Four process Flutter checks passed, including no automatic settings/collection calls in isolated entry. Independent review confirmed the entry semantics. Supplying both workspace flags disables isolated export and is not a supported evidence invocation.

## Observed read-only inventory

A fresh hidden run completed the actual filtered process-inventory path at producer a9975e2d639f0fe37b4fc3c699ad05f9df2a2aee. Delivering the exact filter one character at a time, then inspecting the settled text before refresh, produced a real engine row with memory, cumulative CPU time, UTC start identity and a disabled close control. The native engine start time and owned executable/parent matched the visible row. CIM lost submicrosecond precision, so it was not treated as the exact start-time comparison. No process-close action was invoked. Private frames and input/identity/teardown receipts are retained; runtime identifiers and measurements are not published. Both owned executable paths and the hidden desktop were confirmed closed. The narrow verifier checked 210 bundle files and rejected an altered input-receipt hash before passing restored evidence. Earlier bulk input and modifier-editing attempts remain unsuccessful; this does not prove a full input matrix, close behavior or native compositor capture.

[Sanitized evidence summary](../../verification/process-inventory.json). Run `node scripts/verify-process-interaction.mjs <repository> <private-run> <built-bundle>` against the retained original evidence. The validator verifies bytes and receipt consistency; actual pixel inspection remains a separate assertion.
