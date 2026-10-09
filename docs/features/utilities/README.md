# Local utility workflows

These methods implement bounded local operations. Inputs are validated by the engine; filesystem operations use fixture paths in automated tests.

| Method | Parameters | Behavior |
|---|---|---|
| `files.hash` | `path`, optional `algorithm` (`SHA256`, `SHA384`, `SHA512`) | Streams a file of at most 64 MiB and returns lowercase hexadecimal digest and byte count. |
| `files.convert` | `path`, `outputPath`, `format`, optional `inputEncoding`, `confirmed:true` | Strictly decodes UTF-8/UTF-16LE/UTF-16BE. Supports JSON pretty/compact and encoding conversion. Creates a new output atomically, never overwrites an existing output or the input. Parent output directory must exist. |
| `password.generate` | optional `length` (12..256), `alphabet` (`all`, `alphanumeric`, `unambiguous`) | Generates a fresh value with OS cryptographic randomness. Does not read existing credentials, persist results, or add them to history. |
| `utilities.calculate` | `kind:edpi`, `dpi`, `sensitivity`; or `kind:psu-headroom`, `loadWatts` | Deterministic arithmetic only. PSU result rounds 30% headroom up to 50 W increments and is not a component compatibility assessment. |
| `tools.catalogue` | none | Returns actual implemented workflows and explicit unavailable adapter reasons. Does not claim a full third-party tool catalogue. |
| `providers.configure` | `provider:ollama`, `enabled`, `confirmed:true` | Persists explicit local-provider opt-in, disabled by default. No credentials accepted. |
| `providers.list` | none | Returns configured adapter state. Does not claim the service or models are installed. |
| `providers.invoke` | `provider:ollama`, `action:models`, `confirmed:true`; or `action:chat`, `model`, `prompt`, `confirmed:true` | Calls the fixed loopback Ollama service, without redirects or proxies. Chat is non-streaming, output budget 1024 predictions, response cap 1 MiB, timeout 60 seconds. No prompt or response history logging. |

Example conversion: `{"path":"input.json","outputPath":"formatted.json","format":"json-pretty","confirmed":true}`.
Example calculator: `{"kind":"edpi","dpi":800,"sensitivity":0.5}` returns 400 eDPI.

JSON conversion validates depth up to 64. Invalid encoding or JSON never produces a final output. Cancellation removes the temporary output. UTF conversion does not guess a BOM; select the actual input encoding explicitly. Output paths are user-selected, so this is not an automatic cleanup capability.

CSV/TSV/YAML conversion, lossless image metadata inspection/removal, media inference, and HTTPS AI providers are not implemented. They require real format/provider adapters and, for authenticated remote providers, OS credential storage. No synthetic inference, FPS prediction, or fake availability is returned.

## Verification

`tests/utilities` contains fixture tests for hashing, strict invalid-input rejection, no-overwrite conversion, secure-generator shape, calculator arithmetic, and provider opt-in. Compilation and execution require the integrated root build entrypoint and engine project. No test invokes a provider or accesses user files.
