# Isolated workspace capture tuples

An explicit isolated workspace capture may supply --capture-language=en|yue|both, --capture-theme=light|dark, --capture-text-scale=1|1.25|1.5|2, and --capture-motion=system|reduced. Use exactly one workspace selector and one absolute --capture-frame output. Current selectors are --diagnostics, --processes, --file-use, --scheduled-tasks and --services.

Display overrides are applied only when isolated export is enabled. Duplicate, malformed, unknown or unsupported display options disable export while preserving isolation. Such requests never fall back to loading personal settings. With no display override, existing defaults remain. Normal launches do not apply capture preferences or change persisted settings. No local record is injected or automatically collected.

Text scale composes with the platform text scaler. It is not physical monitor DPI or proof of the complete display-scale matrix. Motion=system respects the operating-system animation preference; it does not force animations on. Reduced motion explicitly disables application transitions. Frame export still records actual painted Flutter output at pixel ratio 1, not native compositor pixels.

Three focused checks cover invalid/repeated values and a dark Cantonese doubled-text reduced-motion service entry with no settings or record calls. Four service checks pass alongside them. Full runtime tuple and layout coverage remains pending.

## Inspected runtime tuple

Root engine and desktop builds passed at 5921f9005cc878ff6ef5753d71b27f8d748f0578. An actual isolated service view in Cantonese, dark theme, text scale 2 and requested reduced motion was inspected at 1264x681. All idle explanatory text and controls fit that viewport. Its receipt verified 210 bundle files; owned processes were absent and the hidden desktop closed. This is one painted idle tuple, not physical DPI, keyboard or motion-transition proof. See docs/captures/services-yue-dark-text2.json.

## Adaptive inspection titles

Inspection title height now follows measured localized text at the requested text scale, using the official AppBar component. Service, scheduled-task and blue-screen selectors use expanded width and intrinsic item height. The original service title fixture measured top -9; the repaired suite passes 240 title combinations (five workspaces, two sizes, three languages, two themes, four text scales) and the selected-value regression. These are widget checks; final rebuilt minimum-size pixels remain pending. A prior real intermediate frame verified the service selector repair while retaining the title defect.

## Minimum-size runtime evidence

Root engine and desktop builds passed at eeaf858395cf171291faa31d0d85c3de206fdb4b. Five real idle workspaces were inspected at an 800×600 client area, English/Cantonese bilingual mode, dark theme, text scale 2 and requested reduced motion. All five complete titles are visible. Content extends below the viewport; these frames do not prove the lower controls, popups, full keyboard flow, physical DPI or motion. Background Page Down did not scroll the service view. Exact bundle processes were absent and all five owned desktops closed. The route used compatibility HTTP/native C++ with identity-checked native resizing and unchanged Flutter painted output, not native compositor capture. See docs/verification/inspection-minimum.json.

## Readable control labels

Search controls on record, process, service and scheduled-task workspaces use the official Material SearchBar with a separate wrapping Material label. Service-state and maximum-record selectors also have wrapping labels above the field. Labels remain visible after input and at enlarged text sizes; search and selection behavior is unchanged. These are registered Material compositions, not replacement input widgets.

Thirteen focused checks passed for label geometry at widths 220, 300 and 752 with doubled text, input preservation and the existing three inspection workflows. Four additional component/layout checks passed, including the 240 title combinations. Rebuilt runtime captures of this refinement remain pending.

搜尋及選單標籤會在控制項上方換行，輸入後仍然可見。已通過上述指定測試；這次調整的重新建置畫面仍待驗證，不能當作完整介面認證。
