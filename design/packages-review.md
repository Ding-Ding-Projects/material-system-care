# Application and package review workspace

The Apps destination is a productive inventory workspace with explicit local refresh and a separate, disclosed WinGet discovery action. A labelled source selector switches between read-only installed applications and exact package matches. Switching source clears the old records and action state.

Use the official Material 3 AppBar, SearchBar, outlined selector, cards, outlined review buttons, AlertDialog and state feedback components. One outer list scrolls at the 800×600 minimum. Long names and bilingual labels wrap. Review dialogs scroll independently while their action buttons remain reachable. Reduced motion follows the shared motion setting.

General inventory cards show name, version, publisher, source and user scope. They have no package mutation action. Managed cards require the exact standard-source package identity and boolean capabilities before exposing a named upgrade or removal review. A missing installed version is explicitly unavailable. No available update is inferred.

Every package review names one exact identifier, the known installed version, the effect and relevant limits. Removal does not create a rollback copy. The engine does not bind mutation to a reviewed installed version. A completed request refreshes the inventory; a failed refresh removes stale actions. Cancellation sends no mutation. Unexpected responses never become success.

Material Designer's required flow is unavailable in this environment. This checked-in specification is the implementation handoff, not rendered evidence. Actual hidden-desktop verification, the complete appearance/state matrix and accessibility checks remain separate.
