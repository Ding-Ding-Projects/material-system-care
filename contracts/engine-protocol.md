# Local engine protocol, version 1

The Flutter interface invokes `invoke` on `MethodChannel('material_system_care/engine')` with `{method: string, params: object}`. The C++ host sends a bounded UTF-8 JSON line to a local named pipe and returns the response JSON string to Dart. The pipe name is `MaterialSystemCare.<current-user-SID>`. The server accepts the current local user only. It does not expose a network listener or arbitrary command execution.

Request: `{"version":1,"id":"opaque-request-id","method":"system.snapshot","params":{}}`.

Success: `{"version":1,"id":"opaque-request-id","ok":true,"result":{}}`.

Failure: `{"version":1,"id":"opaque-request-id","ok":false,"error":{"code":"stable-code","message":"safe explanation"}}`.

Maximum line length is 4 MiB. Validate request versions, method names, object parameters, bounded strings, paths, and operation-specific values before acting. Every request supports cancellation through the connection lifetime and server shutdown. Long operations run away from the UI thread. Indeterminate progress stays indeterminate until a measured result exists.

## Module interface

Namespace: `MaterialSystemCare.Engine`. Module files are under `engine/Modules/` and implement `IEngineModule`:

```csharp
public interface IEngineModule {
    bool CanHandle(string method);
    Task<object?> HandleAsync(string method, JsonElement parameters,
        EngineContext context, CancellationToken cancellationToken);
}
```

`EngineContext` exposes `string DataRoot`, `bool IsElevated`, `Task RecordAsync(string operation, object details, CancellationToken ct)`, and `Task<object?> ReadSettingAsync(string key, CancellationToken ct)`. Modules must not share mutable static request state. Foundation code registers modules explicitly. Additional methods must be documented and communicated before integration.

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
