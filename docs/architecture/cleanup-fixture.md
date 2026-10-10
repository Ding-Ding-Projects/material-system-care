# Disposable cleanup verification

The desktop accepts `--cleanup-fixture-root <absolute-directory>` only as an explicit verification mode. Prepare a unique direct child of `%TEMP%\MaterialSystemCare-cleanup-fixtures`, with existing `temp` and `records` directories. Create `cleanup-fixture.json` with these exact UTF-8 bytes (no BOM or trailing newline):

```json
{"schemaVersion":1,"purpose":"MaterialSystemCare.cleanup-verification"}
```

Put disposable aged test files in `temp`. The engine stores its isolated SQLite database, plans, and recovery records in `records`. The mode never seeds files or infers a fixture from normal startup. Invalid or missing arguments, marker, directories, UNC/device paths, or reparse ancestors prevent engine startup; they never select production storage. Native argument-shape errors exit the desktop, while an invalid filesystem root can leave the desktop open with an unavailable-engine response. Do not use real personal data in the fixture.

For frame export, use the fixture-root arguments with one `--capture-frame=<absolute-png-path>` and the existing capture language, theme, text-scale, and motion options. Fixture mode counts as one capture destination. Adding another destination such as `--services` disables export and display overrides, retaining isolated fixture behavior.

The native bridge supplies a newly generated pipe suffix internally and still requires the server PID to equal its launched child. The engine permits only ping, settings, general history, and cleanup scan/apply/restore/history/details. Host inventory and arbitrary path analysis are unavailable. The desktop shows a bilingual verification banner and the cleanup workspace without normal navigation or personal wording-cache loading.

Retained directory handles bind the root, its ancestors, and its records/temp children to their startup locations. Every dispatch checks their final handle paths and rejects a moved or replaced directory. A retained read-only marker handle prevents replacement. Each dispatch revalidates the scope; ordinary cleanup file-identity and recovery protections remain active. Stop the owned desktop and engine before removing the disposable fixture. This mode enables real workflow verification and does not itself prove runtime or installer coverage.
