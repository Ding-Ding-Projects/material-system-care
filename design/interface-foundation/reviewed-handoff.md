# Material System Care workspace design handoff

Status: proposed design for independent review. No implementation, rendered reference, runtime verification, or release acceptance is established by this document.

## Scope and source baseline

The reviewed baseline is commit `8193fe6ed355b680451dbb91af93ff0c4ee73bba`. Reviewed inputs include `desktop/lib/main.dart`, `desktop/lib/settings.dart`, `desktop/lib/component_registry.dart`, `contracts/engine-protocol.md`, and existing focused design documents for the workspace, cleanup recovery, and package review.

The desktop remains Flutter/Dart, the local engine remains C#/.NET 10, narrowly scoped native integration remains C++20, and SQLite stores local settings and operation records. The browser companion remains TypeScript, Lit, and official Material Web components. Public documentation remains hosted on GitHub Pages. Neither browser controls nor documentation substitute for independently complete desktop controls.

The working design allocation uses `gpt-6-astra` for design and `gpt-6.1-sol` for implementation and independent review. A project-specific routing rule for Material File History does not apply to Material System Care.

The supplied baseline contains 295 capability rows: 278 supported/adapted, 14 excluded, and 3 unavailable vendor engines. Within the supported/adapted set, 233 are unimplemented and 45 are unverified. The supplied surface inventory has 104 features, 34 surfaces, and 2,346 unfinished rows. These are baseline inputs, not newly established acceptance counts. Reconcile the canonical feature inventory before implementation, including the missing `minecraft-server-manager` feature and explicit mappings for six existing public-safe aliases. Never delete or duplicate a requirement merely to make counts match.

## Design direction

Build a productive maintenance workspace around actual records, explicit scopes, contextual actions, and recoverable operations. The initial view shows current observations, active operations, and recovery items. It does not present a marketing hero, a command catalogue, or a universal repair action. A measurement opens a scoped workflow; it never authorizes a mutation.

Use a persistent browser-style tab system, docked left by default and configurable to all four edges. A workspace launcher opens typed task pages. Each task retains its own filters, selection, draft, operation identity, and return-focus target. Navigating away does not silently cancel work or erase a review.

## Source implications

The current `Workspace` selects one destination index and replaces the body with an `AnimatedSwitcher`. Replace index-dependent routing with stable route descriptors and retained task state. Preserve useful focused pages while moving their entry and return paths into the shared shell.

The current settings page is a scrolling card collection. Migrate existing consumers into addressable settings descriptors and real settings tabs. A new visual shell around the same incomplete preference map does not complete the settings contract.

The current component registry lists class names. Extend registration to include component provenance, anatomy, owning surface, stable element identity, supported states, accessibility, appearance properties, motion consumers, and reference coverage. A registered string alone does not prove rendered conformance.

The engine contract already distinguishes request IDs, cleanup plan IDs, original selected indexes, reviewed startup revisions, and cancellation races. Retain these boundaries. Do not replace typed responses with a generic success message or infer an engine capability from an attractive control.

## Persistent shell inventory

IDs below are proposed stable identifiers. They are independent of translated labels, display names, widget instances, and list positions. Repeated records use a stable element template plus a separately bounded record identity.

| Element ID | Component/composition | States and behavior | Connected action/help |
| --- | --- | --- | --- |
| `shell.chrome.surface` | Registered Material surface | Active, inactive, maximized, restored; native hit testing; no input interception over controls | `shell.window.help` |
| `shell.chrome.logo` | Registered image/icon composition | Shipped, custom-loading, custom-valid, invalid; stable installed identity | `settings.identity.logo` |
| `shell.chrome.title` | Material typography | Shipped/renamed display name, long-name wrapping or disclosed shortening | `settings.identity.display-name` |
| `shell.chrome.minimize` | Registered icon-button composition | Enabled, hovered, focused, pressed; accessible name and native minimize consumer | `window.minimize` |
| `shell.chrome.maximize` | Registered icon-button composition | Maximize/restore state and correct native consumer | `window.toggle-maximize` |
| `shell.chrome.close` | Registered icon-button composition | Close review when unresolved work requires a decision; no host power action | `window.close` |
| `shell.launcher` | Material menu/dialog composition | Closed, searching, empty, matching, capability-unavailable | `workspace.open` |
| `shell.tabs.strip` | Registered tab composition | Four dock edges, overflow, reordering, pinned region, groups, persistence | `tabs.manage` |
| `shell.tabs.item` | Tab template | Active, inactive, selected, pinned, grouped, locked, modified, operation-running | `tabs.activate`, `tabs.context` |
| `shell.tabs.group` | Group-header composition | Expanded, collapsed, pinned, locked, renamed; no rotated labels | `tabs.group.manage` |
| `shell.tabs.search` | Search with adjacent anchored regex builder | Plain text, regex-valid, regex-invalid, bounded evaluation, empty results | `tabs.search` |
| `shell.palette` | Bounded card or full-window palette | Search, live setting control, unavailable action, locked target, exact-element teleport | `commands.open` |
| `shell.notifications` | Notification control and persistent review surface | Unread/read, running, completed, partial, failed; dismiss does not delete operation evidence | `notifications.open` |
| `shell.provenance` | Selectable labelled text | Valid version/time, missing/invalid provenance; never launch-clock substitution | `help.about` |
| `shell.content` | Material workspace surface | Loading, ready, empty, unavailable, interrupted; retained task state | Owning route |
| `shell.operation-status` | Originating-workflow progress composition | Measured or explicitly indeterminate, cancel-requested, settled outcome | Owning operation |

All controls receive normal, hover, focus, pressed, and disabled states where meaningful. Selection, dragging, validation, loading, success, warning, and error states are explicitly registered where meaningful. Noninteractive elements still have stable appearance and help/lock targets where applicable. Every action has a keyboard path, visible focus, an accessible name, and a return-focus rule.

The title region separates native draggable space from tab dragging, fields, menus, and caption controls. Native integration supplies resize edges, hit testing, system-menu behavior, maximize/restore semantics, and platform accessibility. Product-owned controls use registered Material Design 3 compositions. Renaming changes display only, never package identity, executable names, update identity, or data paths.

## Workspace routes

| Route | Initial useful content | Workflow |
| --- | --- | --- |
| `overview` | Timestamped measurements, active operations, recovery items | Inspect a source and open its exact workspace |
| `storage` | Selected folder/drive and actual records | Analysis, duplicates, reviewed cleanup, receipt-bound recovery |
| `applications` | Installed records with source and scope | Exact managed matching, upgrade/removal review, refreshed outcome |
| `startup` | Current startup state and reviewed revision | State change review and changed-review recovery |
| `system-inspection` | Process, service, task, and crash observations | Dedicated typed record tabs and only supported actions |
| `protection` | Provider state and collection limitations | Exact supported scan and outcome inspection |
| `drivers` | Driver inventory and action capabilities | Inspection, export, supported installation review |
| `utilities` | Recent/resumable utility tasks | Hashing, conversion, network diagnostics, local generation, external editor handoff |
| `local-models` | Runtime health and installed/running inventory | Complete source-backed catalogue, pulls, chat, supported tools, recovery |
| `servers` | Adopted server inventory and connection/lifecycle state | Four-target Minecraft creation and management |
| `activity` | Persistent operation, notification, and local-history records | Filter, compare, inspect recovery, export, reopen task |
| `settings` | Addressable live settings organized into full tabs | Identity, appearance, language, accessibility, schedules, providers, privacy, locks |
| `help` | Complete offline articles and current-context guidance | Article tabs, search, related actions, exact return target |

## Settings navigation inventory

Settings sections are actual persistent tabs with the same pinning, grouping, docking, overflow, four discovery searches, appearance editing, locking, keyboard navigation, and bulk-close behavior as other tab surfaces.

| Element/section ID | Typed contents | Required states |
| --- | --- | --- |
| `settings.search` | Own search and full anchored regex builder, exact-control results | Empty, matching, no results, invalid pattern, locked target |
| `settings.identity` | Display name, logo presets/local upload, crop/fit/background | Default, edited, saving, saved, invalid, rollback, reset |
| `settings.appearance` | Theme, density, fonts, seed, global presets, element inspector | Inherited, overridden, scheduled, locked, unsupported value retained |
| `settings.language` | Three modes, two independent funny levels, dialog emoji preference | Defaults, changed, persisted, restricted-mode suppression |
| `settings.personal-vocabulary` | Local file upload, replace, clear/reset | No file, loading, valid, invalid/no partial application, cleared |
| `settings.accessibility` | Narration voices/rate/pitch, action sound, text scale, reduced motion | Available, absent voice, late enumeration, unavailable playback, effective value |
| `settings.notifications` | Category preferences and reviewable notification history | Enabled, suppressed category, required error retention |
| `settings.schedules` | Date/time/timezone, weekdays, precedence and source controls | Base, scheduled, external-valid, stale, unavailable, fallback |
| `settings.providers` | Typed configuration, credentials presence only, bounded connection test | Unconfigured, testing, ready, unavailable, disconnected |
| `settings.locks` | Exact per-target policy and credential setup, expiry and recovery | Unlocked, locked, setup, authenticating, expired, unavailable vault |
| `settings.history` | Searchable append-only changes, comparisons, restore review | Empty, recorded, selected, conflict, restored, unavailable |
| `settings.reset` | Scoped reset preview and review | Nothing selected, review-ready, running, partial, complete |

Each setting declares its shipped default, actual consumer, persistence destination, validation, effective value, provenance of overrides, contextual help, history behavior, export boundary, and reset scope. Unsaved or failed persistence is visible. Credentials, personal vocabulary payloads, and custom private image data remain excluded from general history, diagnostics, captures, and exports.

## Typed operation model

Use explicit states: `unavailable`, `idle`, `discovering`, `empty`, `ready`, `selected`, `editing`, `validating`, `review-ready`, `review-stale`, `running`, `cancel-requested`, `cancelled`, `completed`, `partial`, `interrupted`, and `recovery-required`.

Each action descriptor binds a typed input model, target identity, permission/capability requirements, review identity, confirmation requirements, actual engine method, decoder, cancellation semantics, replay behavior, and recovery route. Only relevant states are rendered. An accepted cancellation request is not a settled cancellation; a successful result winning the race remains successful. A disconnected remote server is not a stopped server.

## Typed cleanup review inventory

| Element ID | Control and data binding | State/behavior requirement |
| --- | --- | --- |
| `storage.cleanup.scope` | Guided scope picker | Explains eligible categories; changing scope invalidates the old review |
| `storage.cleanup.scan` | Filled button | Starts `cleanup.scan`; pending state belongs here |
| `storage.cleanup.cancel` | Outlined button | Cancels the exact request ID; requested and settled states stay distinct |
| `storage.cleanup.search` | Search plus full anchored regex builder | Filters visible rows without rewriting original plan indexes |
| `storage.cleanup.results` | Structured selectable result list | Empty, populated, truncated/unavailable metadata explicitly stated |
| `storage.cleanup.result.select` | Checkbox template bound to original index | Selected/unselected/ineligible; stable identity survives filtering |
| `storage.cleanup.result.path` | Labelled selectable path and expandable details | Exact path; wrapping and keyboard-accessible expansion |
| `storage.cleanup.selection.summary` | Material summary surface | Selected count and known bytes, unknown values disclosed |
| `storage.cleanup.review` | Scrollable Material review composition | Exact plan, scope, selected records, effect, recoverability, limitations |
| `storage.cleanup.confirmation` | Accessible destructive-action confirmation composition | Required challenge, partial completion, ready, cancelled; no execution before completion |
| `storage.cleanup.apply` | Filled action | Sends `planId`, explicit `targetIndexes`, and `confirmed:true` only after valid review |
| `storage.cleanup.progress` | Originating-workflow status | Measured where available, otherwise indeterminate; no invented reclaimed capacity |
| `storage.cleanup.outcome` | Per-record outcome list | Moved, skipped, conflict, cancelled, missing-result and partial distinctions |
| `storage.cleanup.recovery.open` | Contextual action | Opens the exact recorded receipt, not a guessed latest receipt |
| `storage.cleanup.recovery.review` | Typed restore review | Readable receipt, exact selected recovery scope, occupied-path disclosure |
| `storage.cleanup.restore` | Confirmed restore action | Invokes `cleanup.restore`; rereads required state before another attempt |

The client never converts omitted selection into all targets. Invalid or stale plans return to a fresh review. Automatic retries never repeat a mutation without its required review. Partial results show requested, recorded, and missing counts when supplied. Recovery conflicts retain recoverable data and explain the next safe action. Unreadable receipts expose no enabled restoration action.

The engine revalidates cleanup path identity, size, modification state, and allowed category. The interface states that optimistic review does not turn a filesystem operation into an atomic global transaction. Preserve recoverable data and report actual outcomes.

## Appearance and motion studio

Every rendered element has an accessible context action opening a nonmodal anchored editor for that exact identity. The editor follows its anchor, resolves viewport collisions, retains return focus, and can target its own controls. One editor instance has one explicit active target to avoid accidental recursive target changes.

Real editor tabs: Target and States; Typography; Colour and Fills; Layers; Layout; Animation and Transition; History and Portability. Each tab has its own applicable searchable controls and full regex builder. Normal tab management remains available.

The capability inventory includes full installed/bundled font discovery and typography; continuous colour editing and all required colour-space translations; layers/groups, masks, selections, channels, effects, adjustments, embedded content, transformations, geometry, gradients and image fills; layout and shape; complete animation tracks, keyframes, timelines, timing, easing, triggers, sequencing, conflicts, playback, interruption, and reduced-motion equivalents.

Every property maps to an actual renderer consumer. Unsupported properties remain visible with an exact platform explanation, portable input preservation, and an unavailable preview. Saving a property does not prove it was applied. Flutter renderer behavior and browser CSS behavior require separate adapters and evidence; neither is inferred from the other.

Provide per-property, per-layer, per-state, per-element and global reset; undo/redo; append-only local history; named presets; validated import/export; copy/paste style; schedules; contrast diagnostics; bounded preview resources; and source-safe handling of private custom data. Reduced motion retains authored values separately from safe effective rendering.

## Four-target Minecraft manager

The canonical feature ID is `minecraft-server-manager`. The four targets are local Windows process, local Docker container, SSH process, and Docker container on an SSH host. This explicit server-management scope does not enable unrelated remote-device administration.

Creation: choose target and verify readiness; choose edition/channel/version/flavour from complete authoritative discovery; resolve runtime/platform compatibility; configure paths, storage, ports and permissions; review licensing, installation effects and recovery; install with real progress/cancellation; validate readiness before lifecycle actions.

Adoption is separate, read-only discovery followed by explicit ownership consent. An opened server provides Overview, Configuration, Worlds, Extensions, Players and Permissions, Networking, Schedules, Logs, Commands, Backups, and History tabs. Configuration descriptors bind versioned source facts, type, bounds, units, valid choices, defaults, live/restart behavior, permissions, help, and consumers. Boolean switches, enumeration selectors, numeric controls, structured collection editors, file pickers, permission matrices, and dedicated complex builders replace generic text-only configuration.

Discover all historical/current distributions and future catalogue updates without a curated ceiling. Preserve source/version identities, pagination completeness, stale/offline states, unavailable distributions, and unknown compatibility. Extensions require provenance, integrity where available, compatibility, transactional installation, rollback, and truthful management coverage. Back up before consequential world/version/flavour changes. Never imply downgrade safety without evidence.

Acceptance is edition × version × flavour × target × extension bound. Samples do not establish every untested version. No target or workflow is accepted by this design document.

## Responsive and accessible layout

Normal desktop client area: 1280 × 900 logical pixels. Existing documented minimum: 800 × 600. A left strip begins around 200 logical pixels at the normal size; selected records may reveal a contextual inspector. At the minimum, use compact tab presentation, move the inspector into a bounded overlay or dedicated tab, stack review fields, and retain reachable actions while review content scrolls. Preserve one primary record scroll region. Never fit bilingual content by silently shrinking typography.

The browser companion covers approximately 320 pixels upward. It independently implements applicable settings, navigation, search, appearance, help, and records. Locally mediated actions disclose their readiness and connection boundary. A static page cannot claim direct ownership of a local process, SSH authentication, or a Docker daemon.

## Required features still open

This handoff specifies architecture and the bounded shell/settings/cleanup starting slice. It does not accept remaining maintenance capabilities or shared requirements. Outstanding requirements include all language and voice modes; restricted mode and unlock flows; personal vocabulary; narration; scheduled settings; logo editing; full appearance and motion tools; search and complete regex builders; every tab/group/discovery/bulk operation; per-element locks and authentication; contextual guidance; notification history; local history; comprehensive exports; converters; local model management; server management; external editor integration; documentation and changelog viewers; complete contextual help; accessibility; real status reporting; and current presentation evidence.

Do not hide these requirements behind global settings, generic controllers, capability labels, or representative demonstrations. Each applicable feature/surface pair needs an implementation consumer and its own acceptance record. Excluded and unavailable capabilities retain exact reasons. Public documentation must contain the complete supported article/wiki inventory and link through working internal routes.

## Planned target-owned references

After canonical naming and independent review, place approved files in the target repository's own `design/` directory: `workspace-shell.md`, `workflow-state-model.md`, `element-action-registry.md`, `appearance-studio.md`, `motion-studio.md`, `server-manager.md`, `settings-navigation.md`, `companion-boundaries.md`, `reference-inventory.json`, and `acceptance-map.json`.

The reference inventory records route/state IDs, viewport, scale, language, theme, motion, provenance, and asset identity. The acceptance map connects feature to element/action, actual consumer, focused checks, and rendered evidence. Preserve existing focused references and historical captures until replacements are implemented and verified; do not relabel historical evidence.

## Verification requirements and limitations

For every inventoried desktop screen/state, cover two client areas × three language modes × two themes × four display scales (100%, 125%, 150%, 200%): 48 layout tuples before reduced-motion variants. Record physical display scale separately from text scale. Include long labels, paths, empty and large collections, overlay collision, tab overflow, scroll ownership, action reachability, visible focus, and keyboard return paths.

Bind captures to the exact source commit, build receipt, binary hash, route/state, client area, language, theme, display/text scale, motion preference, capture method, and privacy verdict. Flutter requires actual render-tree/platform geometry and native evidence. Browser DOM geometry alone does not prove desktop layout.

Interaction verification covers persistence, stale reviews, cancellations and races, partial outcomes, recovery, each search/regex pair, locks across every activation route, palette teleport, every appearance/motion consumer, and each server compatibility boundary. Motion needs timed or sampled-render evidence with trigger/timing assertions, not just a final still.

Negative completeness checks deliberately remove required controls, consumers, states, targets, or inventory rows and must fail before restoration passes. Independent design review is pending. No build, runtime interaction, screenshot, physical-scale check, accessibility session, packaged installation, publication, or release verification was performed for this draft.
