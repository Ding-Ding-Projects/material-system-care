# Read-only resource sample

`system.performance` accepts an optional integer `intervalMs` from 250 through 2000, default 500. Unknown, duplicate, fractional and out-of-range parameters are rejected. Cancellation interrupts the sample delay. It never changes priority, terminates processes, changes power settings or performs optimization.

The response includes UTC `observedAt`, `requestedIntervalMs`, actual monotonic `measuredIntervalMs`, `fixtureDataRoot`, `cpu`, `memory`, `mutationPerformed:false` and a limitation. CPU usage uses the difference between two supported `GetSystemTimes` readings. Kernel accounting already includes idle time; idle is subtracted once from kernel plus user time. Reversed counters, zero elapsed accounting, arithmetic overflow or idle greater than its containing kernel delta return `available:false` and a reason, not an invented zero. CPU percentages are rounded to two decimal places.

On systems with more than 64 logical processors, `GetSystemTimes` is scoped to the calling thread's primary processor group. This API does not guarantee whole-machine accounting on those systems. `logicalProcessors` reports the process runtime's processor count and does not widen that measurement scope. The response explicitly discloses this limitation.

Physical memory uses one end-of-interval `GlobalMemoryStatusEx` snapshot. It returns available and total physical bytes and load percentage, or an unavailable reason. This is not a CPU average over a session, a per-process attribution, GPU or temperature telemetry, disk throughput, a benchmark or proof that optimization is advisable. The interface must display the actual interval and limitations and avoid overlapping indefinite polling.

The local-only response is not written to general history. Synthetic arithmetic fixtures check idle accounting, reversal, overflow and impossible values. A bounded 250 ms live read verifies response structure, elapsed measurement and either measured CPU percentage or its actual unavailable state. No host mutation runs during verification. Built desktop charts and long-session observation remain separate acceptance work.
