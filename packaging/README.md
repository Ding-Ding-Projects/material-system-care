# Windows packaging

`build-installer.bat /s` builds the self-contained .NET engine, Flutter desktop and public website, then creates genuine unsigned Squirrel.Windows `Setup.exe`, `RELEASES`, and full NuGet packages. `BUILD_VERSION` optionally supplies a unique three-part numeric SemVer version with each component between 0 and 65535. Validation runs before tool bootstrap or compilation. Squirrel.Windows 2.0.1 rejects four-part NuGet versions. The workflow uses `0.<run_number>.<run_attempt>`, and both engine and desktop receipts record the selected version. Packaging never publishes a release. Hidden Squirrel execution waits for its real exit code and retains stdout, stderr, and the current invocation's releasify log under `artifacts/installer/diagnostics`, including on failure.

The package includes the native desktop, Flutter resources, and `engine/MaterialSystemCare.Engine.exe`. The native host starts only this sibling engine and owns its process lifetime through a Windows job object. IPC uses the current user's SID pipe, validates the method envelope, limits messages to 4 MiB, performs blocking operations on worker threads, and delivers completions on the UI thread.

Squirrel 2.0.1 and NuGet 6.14.0 downloads use pinned SHA-256 checks. The installer is unsigned and can trigger unknown-publisher or SmartScreen warnings. A successful package build is not an installation or update verification receipt.

Packaging uses a project-owned helper composition, not an unchanged stock Squirrel tool directory. Each attempt preserves a fresh extraction of the original, hash-verified Squirrel.Windows 2.0.1 archive and creates a separate active tools copy. Its Squirrel assembly remains unchanged. The active copy supplies official standalone 7-Zip 26.04 under the `7z.exe` helper filename that Squirrel's assembly-directory lookup requires. The official Extra archive and extracted x64 executable/DLL have pinned SHA-256 values; there is no global installation or replacement of the preserved original tools. This addresses an observed CRC metadata failure in the stock 16.04 toolchain, while the original payload bytes remained intact. The composition must still pass the actual root installer producer before it is considered verified for a candidate.

Both raw and full packages are independently decompressed and checked before promotion. Every ZIP entry must have valid CRC and length metadata, every bundle-manifest payload must be present with its exact length and SHA-256, and the embedded engine/desktop receipts must match the selected source and version. A successful Squirrel process and matching RELEASES hash alone are insufficient. The validator never edits a ZIP or a finished Setup executable. `node scripts/verify-package-crc.mjs` covers intact payload bytes with deliberately wrong ZIP CRC metadata, changed payload with valid CRC, and missing payload.

Native transport uses total bounded method deadlines: security scans allow one hour, storage/cleanup operations 30 minutes, provider calls 70 seconds, package/driver changes four minutes, and other methods one minute. No individual read restarts the deadline. Optional invocation `id` identifies an active operation; native channel `cancel` with that id stops its pipe connection within approximately 100 milliseconds. Closing the workspace cancels every active transport before joining workers. Engine cancellation follows connection lifetime. The `build.bat /s --target=native` fixture covers a genuine 31-second terminal response, a deterministic short timeout, explicit cancellation, and deadline selection without launching a desktop or changing host settings.

The release workflow builds and packages on Windows and runs no tests or lint. Pushes and ordinary manual dispatches retain build outputs without publishing a production release. Publication requires a manual dispatch on `main`, an explicit publication choice, the exact verified candidate SHA, and complete hashed capability evidence in `release-readiness.json`. Its initial unverified entries deliberately prevent unfinished production activation. Evidence validation does not run tests or replace runtime verification.

The native client accepts only the PID of the engine launched by that workspace, checks it with GetNamedPipeServerProcessId before sending request bytes, and restricts server impersonation with identification-only SQOS. It does not attach to an arbitrary same-user pipe server. The isolated fixture proves rejection of a same-user server with a different expected PID. Squirrel awareness uses the exact English Unicode resource block queried by pinned Squirrel 2.0.1 (040904B0); build and package entrypoints validate the built resource. Real installation and lifecycle execution remain separate pending runtime proof.

Product branding retains its source at packaging/assets/mark.svg. Run powershell.exe -NoProfile -File scripts/render-product-icon.ps1 to reproduce the native 16/32/48/256-pixel ICO using the platform vector drawing API. The renderer validates the source geometry before conversion. Full bundle manifests use ordinal relative-path ordering and SHA-256 for every produced payload file, including AOT data/app.so, assets, Flutter runtime and engine files. Receipt and manifest files are excluded only at their defined root/engine locations to avoid self-reference. Packaging validates the exact inventory and hashes; build.bat /s --target=bundle proves changed AOT bytes and unexpected files are rejected.


## Latest bounded package check

`build-installer.bat /s` completed at source `4db8f8c2e93534433c45acfc60ae8914c8fbe4ef`. The raw archive had 218 entries; the full Squirrel package had 231 entries and matched all 210 intended payload files. `RELEASES` length and SHA-1 matched the package. `Setup.exe` reported `NotSigned`. [The recorded hashes and limitations](../docs/verification/installer-build.json) distinguish this package check from installation proof.

No release is published. A disposable operating-system user/VM or documented isolated installation root has not been established. Installation, update, uninstall, complete build-log provenance and signing-process observation remain unverified. Do not redirect `LOCALAPPDATA` to pretend the real per-user Squirrel installation is isolated.

中文：指定來源嘅正式安裝建置入口已完成，套件內容同雜湊已核對，安裝程式未簽署。未建立合適嘅即棄安裝邊界，所以實際安裝、更新、解除安裝仍未驗證，亦未公開發行。

## Lifecycle result handling

The desktop now checks updater launch, wait, and exit results rather than
reporting every Squirrel lifecycle event as successful. See
[the lifecycle contract](../docs/features/management/squirrel-lifecycle.md) for
recognized events, fixed shortcut arguments, path checks, and the ten-second
wait limit. A timeout reports failure without terminating the updater, which
may still complete later. Native controlled-child tests do not replace actual
installation, update, shortcut, and uninstall verification.
