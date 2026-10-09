# Website design and controls

Material Designer's required local flow was unavailable for this task. This checked-in handoff preserves the target-owned implementation reference. It describes intended behavior, not verified pixels.

## Component registry

| Composition | Material implementation | States and motion |
| --- | --- | --- |
| Primary navigation | Official md-tabs and md-primary-tab | Selected indicator, keyboard focus, route change; reduced preference removes animation |
| Actions | md-filled-button, md-filled-tonal-button, md-outlined-button, md-text-button | Enabled, hover, pressed, focused, disabled; Material state layers |
| Searches and pattern fields | md-outlined-text-field | Empty, input, focused, invalid/deadline status; anchored inline builder |
| Options | md-outlined-select and md-select-option | Expanded, selected, focused, disabled; official Material popup |
| Row selection | md-checkbox | Checked, unchecked, keyboard focus; source records retained verbatim |
| Motion preference | md-switch | On/off, keyboard focus, persisted state |
| Preferences and commands | md-dialog | Open, close, Escape, focus restoration through official component |
| Static cards, notices, records | Specification-backed Material surface, typography and state-layer compositions | Surface/container roles, outline and 24–32 px shape; no custom visible generic control |
| JSON picker | Invisible semantic file input activated by an official Material button | Chosen, loaded, invalid, replace, clear; no filename displayed or persisted |

Every action updates state immediately, uses official Material state layers, or performs explicit navigation. Decorative entry motion uses standard/emphasized easing. Both the persisted reduced preference and operating-system reduced-motion media query remove nonessential animation and smooth scrolling.

## Search and exports

Capability search defaults to plain text. Its adjacent regex panel synchronizes pattern and query, supports JavaScript i/m/s/u flags and insertion helpers, and evaluates only in disposable workers. Each evaluation limits patterns to 256 characters, input to 4096 records of 4096 characters each, and terminates after 150 ms. Generation checks prevent stale results. Preferences and command searches own separate anchored regex controls and ephemeral state.

This is a bounded regex editor, not the complete advanced regex workbench. Parse trees, capture tables, replacement previews, saved cases, tracing, and match navigation remain unfinished. Select dropdown filtering and element-specific context/appearance menus also remain unfinished.

Users can select individual or all filtered capability records and export the selected filtered rows in JSON, CSV, Markdown, or TXT. Export uses original catalogue records, never personal wording or file metadata. The visible catalogue retains factual source wording in all language modes.

## Local wording schema

The complete file is validated before changing the active cache. UTF-8 JSON has exactly schemaVersion (1) and entries (an object), maximum 256 KiB, maximum depth 2, 4096 entries, 160-code-point nonempty keys and 1000-code-point string values. Arrays, unknown fields/versions, duplicate keys, unsafe object keys, malformed UTF-8 and control characters in replacement values are rejected. A bad replacement file retains the last valid cache. Corrupt cache is purged on load. Clearing removes the private local cache and restores shipped copy. The source filename is never retained. Parsing, validation and application make no network requests. No real personal mappings or example payloads are checked in. Rendering makes one literal longest-match pass over original authored text. Inserted values are never reprocessed. A transformed field exceeding 16,384 UTF-16 code units falls back atomically to the unchanged original field; it never displays partial transformed text. Matchers are cached only in private memory.

## Evidence boundary

Release metadata remains development with no installer URL. A source build is not installer verification. Runtime interaction, mobile and high-scale layout, all language/theme tuples, accessibility, full feature-contract parity, and genuine screenshots require the mandated isolated cheap Lowlevel route and remain unverified. No browser automation or substitute screenshots were used in this lane.
