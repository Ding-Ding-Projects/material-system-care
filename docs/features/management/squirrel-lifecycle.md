# Squirrel lifecycle result handling

The Windows entrypoint handles `--squirrel-install`, `--squirrel-updated`,
`--squirrel-uninstall`, and `--squirrel-obsolete` before Flutter starts. Unknown
`--squirrel-` events and multiple lifecycle events return a nonzero result.
Ordinary startup arguments remain available to Flutter. Additional arguments are
never forwarded to the updater.

Install and update request `--createShortcut material_system_care.exe` from the
installation root's `Update.exe`. Uninstall requests the corresponding fixed
`--removeShortcut` action. The module path must be an absolute local drive path,
with the expected executable name, a version directory, and an installation
parent below the drive root. Relative paths, network/device paths, alternate
streams, quotes, control newlines, and dot traversal components are rejected.
The exact updater path is passed as `CreateProcessW`'s application name, so no
PATH search chooses the executable. Missing files and directory targets fail.
The installed updater is not cryptographically authenticated by these checks.

The launcher owns both native handles with automatic cleanup. A failed process
creation, failed wait, failed exit-code read, or ten-second timeout returns
nonzero. An observed child exit code is propagated when representable as a
positive `int`; larger codes map to a nonzero process-aborted result. Obsolete is
a successful no-op and never resolves or launches an updater.

A timeout closes the launcher's handles without terminating the updater. The
updater may therefore finish its action after the launcher has reported failure;
a timeout must not be described as rollback or proof that nothing changed.

## Verification boundary

The root native build runs a controlled executable for success, exit code 23,
missing executable, and a short timeout. It also checks event rejection and path
validation. The timeout child exits itself; the fixture never kills a production
process. These tests do not install the application, create current-user
shortcuts, download updates, or establish end-to-end Squirrel installation,
update, and uninstall behavior. Actual operating-system wait and exit-query
failures remain defensive branches, not induced runtime evidence.
