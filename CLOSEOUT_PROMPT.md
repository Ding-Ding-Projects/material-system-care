# Automatic release publication

## Objective

Publish one normal GitHub Release after each successful push build from `main`. Keep other branch builds release-free, retain manual publication, use the exact source SHA built, preserve the unsigned Squirrel.Windows disclosure, and keep the existing installer files attached.

## Current source state

Normal release `v0.117.1` was published from exact source `5abc3f9d82f2400dade7b4e27e592be8690c0b1a` after successful run `38201159732`; its tag, normal-release flags, four expected files, and unsigned-installer disclosure were read back. Earlier release `v0.116.1` also passed the same checks from `4bd2a144c993d0bfa7ccaa10d7df92cc8dfc66a9`. Both releases' timing notes were corrected to the verified package-job start and published timestamps. Documentation run `38201159733` succeeded; the current homepage, release article, and three local assets returned HTTP 200, and the stored About homepage matches the deployed URL. A workflow timing correction is prepared locally; the next normal release must verify its automatic timestamp calculation. No tests or lint run were added.

The workflow publishes `Setup.exe`, `RELEASES`, the full `.nupkg`, and the tracked catalog photo after its catalog, checksum, tracking, and image-decoding checks. The image's attribution and license are recorded in the catalog and release notes. Actual installation, update, and uninstall behavior remain unverified.

## Integration and preservation

The primary `main` checkout had seven local commits ahead of the fetched `origin/main` before this task. The maintenance-engine branch at `462bd4e52240ae74fe2f02d392ad64d3b74b15c1` has been pushed and read back, and remains preserved because it adds product protocol operations excluded from this task. The desktop-ui branch's generated registration files exactly match current `main`; ancestry merge `9a2555b` records that history without changing the tree. The cleanup-fixture, startup-ui-checkpoint, and interface-foundation tips are ancestors of `main).

Before any cleanup, create and verify a complete repository archive containing the primary checkout, every linked checkout, and all version-control administrative data. Remove only candidates with confirmed task ownership, preserved contents, completed integration, a successful push, and an ancestry proof against the pushed `main`. Keep any active or ownership-uncertain candidate and explain why.

## Next actions

Integrate the reviewed maintenance-engine changes and redundant generated registration history without reverting current `main`. Update this prompt with the latest handoff before the final integration push. Read back `main`, the resulting GitHub Actions run, the normal release, its exact tag target and downloadable files, and the documentation deployment. Then archive, prove ancestry, and process only safely owned cleanup candidates.
