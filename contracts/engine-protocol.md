# Local engine protocol, version 1

The Flutter interface invokes `invoke` on `MethodChannel('material_system_care/engine')` with `{method: string, params: object}`. The C++ host sends a bounded UTF-8 JSON line to a local named pipe and returns the response JSON string to Dart. The pipe name is `MaterialSystemCare.<current-user-SID>`. The server accepts the current local user only. It does not expose a network listener or arbitrary command execution.

Request: `{"version":1,"id":"opaque-request-id","method":"system.snapshot","params":{}}`.

Success: `{"version":1,"id":"opaque-request-id","ok":true,"result":{}}`.

Failure: `{"version":1,"id":"opaque-request-id","ok":false,"error":{"code":"stable-code","message":"safe explanation"}}`.

Maximum request and response JSON length is 4 MiB in UTF-8, excluding the line terminator. The connection-owned parser uses 16 KiB chunks and retains subsequent lines. Success serialization independently enforces the response bound; an oversized result returns `RESULT_TOO_LARGE`, so clients can narrow scope or request individual records. Aggregate settings and history queries also stop before accumulating excessive data. Validate request versions, method names, object parameters, bounded strings, paths, and operation-specific values before acting. Every request supports cancellation through the connection lifetime and server shutdown. Long operations run away from the UI thread. Indeterminate progress stays indeterminate until a measured result exists.

## Module interface

Namespace: `MaterialSystemCare.Engine`. Module files are under `engine/Modules/` and implement `IEngineModule`:

```csharp
public interface IEngineModule {
    bool CanHandle(string method);
    Task<object?> HandleAsync(string method, JsonElement parameters,
        EngineContext context, CancellationToken cancellationToken);
}
```

`EngineContext` exposes `string DataRoot`, `bool IsElevated`, `Task RecordAsync(string operation, object details, CancellationToken ct)`, and `Task<object?> ReadSettingAsync(string key, CancellationToken ct)`. Modules must not share mutable static request state. `Program.ModuleInventory` explicitly registers six module types and 37 allowed methods. It drives construction, dispatch ownership and `engine.ping.capabilities`; arbitrary assembly/plugin discovery is not supported. Additional methods must enter that inventory and its consistency regression before integration.

## Initial methods

| Area | Methods | Minimum response |
| --- | --- | --- |
| Core | `engine.ping`, `system.snapshot`, `settings.get`, `settings.save`, `history.list` | Version/capabilities; CPU, memory and drives; settings object; chronological operation records |
| Storage | `storage.analyze`, `storage.duplicates`, `cleanup.scan`, `cleanup.apply`, `cleanup.restore`, `cleanup.history` | Real file summaries; exact-match duplicate groups; approved cleanup plan; recovery receipt |
| Management | `apps.list`, `apps.updates`, `apps.upgrade`, `apps.uninstall`, `startup.list`, `startup.set`, `processes.list`, `processes.stop`, `services.list` | Records with stable identifiers, capabilities, and per-operation results |
| Security and drivers | `security.status`, `security.scan`, `drivers.list`, `drivers.export`, `drivers.install`, `network.diagnostics` | Actual platform state with unavailable reasons; explicit operation receipts |
| Utilities | `files.hash`, `files.convert`, `password.generate`, `tools.catalogue`, `providers.list`, `providers.configure`, `providers.invoke` | Validated local output or clearly disclosed provider result |

## Operation boundaries

Analysis never implies consent to change a computer. Mutating methods require an explicit `confirmed: true` plus the selected stable target. Cleanup is restricted to server-issued plans whose root, path identity, size, modification state, and allowed category are revalidated at application time. Cleanup moves eligible data to recoverable storage; it does not permanently remove user documents.

No bulk registry deletion, security disabling, forced process termination, or power/login action is part of automatic maintenance. User-facing operations that require elevation return `ELEVATION_REQUIRED` until the approved broker path is available. External executables use fixed names and argument lists, never a shell command composed from user input.

Settings and history use SQLite below the user's local application data. Private vocabulary data and credentials never enter general history, diagnostic output, screenshots, or exports. A fixture data root may be supplied for automated verification; fixture use must be labelled and cannot masquerade as live machine measurements.

## Crash diagnostics

`diagnostics.crashes` accepts `{days: 30, limit: 50}` with integer ranges 1–365 and 1–100. It returns `collectedAt`, `lookbackDays`, `eventLimit`, `events`, `dumps`, `warnings`, `dumpContentsRead: false`, `uploaded: false`, `rootCauseEstablished: false`, `timeMeaning`, and `limitation`. Event rows contain record ID, recorded UTC time, provider-qualified event ID, evidence kind and optional stop-code explanation. Dump rows contain name, bytes, modification time and `analysis: metadata-only`. No raw event messages, addresses or dump bytes are returned.

`diagnostics.explainStopCode` accepts `{code: "0x0000009F"}` or a decimal string. It returns hexadecimal and decimal values, the known name/category or an explicit unknown result, confidence limitation, next checks and the Microsoft reference URL. It performs no host collection. Neither method mutates the computer, uploads data or persists its response to general history. See [the investigation guide](../docs/features/diagnostics/blue-screen.md).
