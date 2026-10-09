# Windows packaging

`build-installer.bat /s` builds the self-contained .NET engine, Flutter desktop and public website, then creates genuine unsigned Squirrel.Windows `Setup.exe`, `RELEASES`, and full NuGet packages. `BUILD_VERSION` optionally supplies a unique numeric package version. Packaging never publishes a release.

The package includes the native desktop, Flutter resources, and `engine/MaterialSystemCare.Engine.exe`. The native host starts only this sibling engine and owns its process lifetime through a Windows job object. IPC uses the current user's SID pipe, validates the method envelope, limits messages to 4 MiB, performs blocking operations on worker threads, and delivers completions on the UI thread.

Squirrel 2.0.1 and NuGet 6.14.0 downloads use pinned SHA-256 checks. The installer is unsigned and can trigger unknown-publisher or SmartScreen warnings. A successful package build is not an installation or update verification receipt.

The release workflow builds and packages on Windows and runs no tests or lint. Each successful run publishes a distinct version. This prioritizes delivery: a release may come from source whose local tests would fail.
