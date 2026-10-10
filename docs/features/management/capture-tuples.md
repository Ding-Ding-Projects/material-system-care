# Isolated workspace capture tuples

An explicit isolated workspace capture may supply --capture-language=en|yue|both, --capture-theme=light|dark, --capture-text-scale=1|1.25|1.5|2, and --capture-motion=system|reduced. Use exactly one workspace selector and one absolute --capture-frame output. Current selectors are --diagnostics, --processes, --file-use, --scheduled-tasks and --services.

Display overrides are applied only when isolated export is enabled. Duplicate, malformed, unknown or unsupported display options disable export while preserving isolation. Such requests never fall back to loading personal settings. With no display override, existing defaults remain. Normal launches do not apply capture preferences or change persisted settings. No local record is injected or automatically collected.

Text scale composes with the platform text scaler. It is not physical monitor DPI or proof of the complete display-scale matrix. Motion=system respects the operating-system animation preference; it does not force animations on. Reduced motion explicitly disables application transitions. Frame export still records actual painted Flutter output at pixel ratio 1, not native compositor pixels.

Three focused checks cover invalid/repeated values and a dark Cantonese doubled-text reduced-motion service entry with no settings or record calls. Four service checks pass alongside them. Full runtime tuple and layout coverage remains pending.
