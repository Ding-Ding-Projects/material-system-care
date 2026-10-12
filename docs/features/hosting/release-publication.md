# Windows release publication

Every push and manual dispatch builds and packages the Windows installer. A successful push to `main` publishes one normal GitHub Release from the exact `github.sha` built by that run. Pushes to other branches remain build-only.

Manual publication remains available on `main`. The operator must select publication, and the supplied candidate SHA must exactly match the checked-out `github.sha`. Capability-readiness data reports implementation status but does not decide whether publication can proceed.

Each release uses the workflow's unique `0.<run_number>.<run_attempt>` version and includes `Setup.exe`, `RELEASES`, the full `.nupkg`, and one image selected from the tracked `packaging/assets/dim-sum-catalog.json` catalog. The workflow checks the image's source-tree tracking state, SHA-256, and decodability before publication. The catalog records attribution, license, source, and checksum. The Squirrel.Windows installer is unsigned. Unknown-publisher and SmartScreen warnings may appear. The workflow runs no tests or lint, so a successful build is packaging evidence, not a claim that installation, updates, uninstall, or complete product behavior were verified.

The catalog image is [Dim Sum.JPG](https://commons.wikimedia.org/wiki/File:Dim_Sum.JPG), credited to Benreis and licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/). The release notes identify the image and its attribution.

Publication fails if the build or packaging fails, manual candidate selection does not match the built commit, a release tag already exists, or GitHub CLI publication fails. The workflow does not create draft or prerelease releases. After publication, verify the release through `gh`, including its normal-release flags, tag target, source SHA, and downloadable installer assets.
