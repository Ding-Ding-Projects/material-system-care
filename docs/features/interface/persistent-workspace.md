# Persistent maintenance workspace foundation

The desktop opens a productive overview with explicit measurement actions. The workspace menu opens the existing typed pages, including recoverable cleanup, storage analysis, duplicate analysis, packages, startup, protection, drivers and system inspection. These pages retain their existing engine contracts and limitations.

## Routing and live state

Every open task has a stable tab identity. An `IndexedStack` keeps filters, selections and current reviews alive when another tab becomes active. Tabs support pinning, groups, group collapse, context-menu reordering, search, close review and docking on four edges. One route opens one retained tab; this foundation does not yet support duplicate instances of the same route. Closing a tab explicitly warns that session state is discarded and a local engine request may still be finishing. Native application close and the system-menu close action use the same review boundary.

The local engine settings APIs store version-1 `workspaceTabs` metadata. The consumer bounds it to 24 tabs, known routes, unique bounded identifiers, 48-character group names and a valid active identity/dock. Invalid or unavailable saved data leaves the current initial session usable with a visible explanation. Save failures remain visible with retry. Only route metadata is persisted. Record paths, filter contents, cleanup plans, selected targets, results, personal wording and credentials never enter this cache. Restart restores navigation and performs each page's normal initial behavior; it does not replay an operation.

## Window integration

Flutter renders accessible Material caption buttons and a dedicated title gesture region. The native C++ channel implements drag, minimize, maximize/restore, native system menu and reviewed close. The native host removes its nonclient caption, retains the sizing frame, forwards edge hit testing from the Flutter child, constrains the window to 800 by 600 logical pixels and uses the monitor work area when maximized. Initial size is 1280 by 900. The title drag region does not overlap fields, tabs or caption buttons. Double-click maximizes/restores; right-click opens the system menu. Native resizing, focus, accessibility, maximize, Alt+F4 and system-menu behavior require live Windows verification before acceptance.

## Registered elements and copy

`shell_elements.dart` declares stable IDs, Material component/composition provenance, help IDs, applicable states, actions and motion ownership for the named shell elements. `RegisteredElement` rejects unknown IDs and binds the declaration to a rendered keyed subtree. Material controls own hover, focus, press and selection state layers. This is an initial rendered inventory, not universal appearance/lock/help acceptance for every descendant. Existing global language, theme, density, text scale, reduced-motion and local personal wording consumers remain active. New shell copy has Cantonese translations and uses the same three-mode consumer.

## Cleanup boundary

The shell opens the existing `CleanupWorkspace` directly. It preserves `cleanup.scan`, server-issued plan scope and expiry, original target indexes, per-target review, `cleanup.apply`, exact request cancellation, per-record outcome validation and receipt-bound recovery. Switching tabs does not discard an active review or request. No generic command field or implicit all-target selection is introduced.

## Verification and remaining acceptance

Focused routing tests prove bounded round trips, invalid cache rejection, retained drafts and exclusion of draft text from saved metadata. The updated workspace test checks explicit navigation and honest unavailable state. Existing cleanup checks cover scope, target/receipt identity, cancellation races, stale review and minimum bilingual/reduced-motion layouts.

The foundation remains unverified for production. The 48-tuple built capture matrix, window accessibility/native interaction receipt, all nested rendered-element inventory, complete settings tabs/editors, anchored full regex builder, command palette, tab/group locks, element appearance/history and independent humor/dialog emoji consumers remain acceptance gaps. No surface-feature row is marked verified by this article. The capability catalogue and its exclusion/unavailable counts are unchanged.
