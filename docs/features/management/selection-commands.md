# Text selection commands

Material System Care uses Flutter's standard Material text-selection toolbar. The seven default commands, Copy, Cut, Paste, Select all, Look Up, Search Web and Share, follow the current English, Cantonese or bilingual wording preference.

The application supplies the current language and validated local wording mapping to a Material localization delegate. An immutable snapshot prevents later mutation of the input map from changing an already-loaded value. Replacing or clearing the wording preference reloads dependent toolbars. The delegate relies on the existing settings validator; it is not an independent arbitrary-settings sanitizer.

Flutter still decides which commands are available and owns selection, callbacks, clipboard access, placement and dismissal. Explicitly labelled custom commands retain their own labels. Other inherited Material messages and operating-system menus are not covered by this seven-label change.

## Verification

The source candidate `638a56000ad88b429c4216c63f192468000e4d8c` passed 21 focused checks and its exact root desktop build. Tests exercise all seven labels in three language modes, preference snapshot and reload behavior, an actual Apps search-field toolbar at 800×600 with doubled text, a language change while open, reopening, standard Copy and Select all callbacks, and preservation of an explicit custom label. Clipboard calls are mocked. Two independent source reviews found no concrete defect in this bounded change.

The integrated root desktop build passed at `9bf5d30c98c6e0fcf3ac13cc446618e9bc5d32a4`. A real 800×600 hidden-desktop run with doubled bilingual text showed Select all, Cut and Copy in both languages, fully within the viewport. Select all highlighted the complete synthetic input; Escape dismissed the toolbar and Backspace cleared the selection. No inventory was loaded and no clipboard action was invoked. Six inspected frames and twelve supporting records passed the narrow source/bundle/two-hook verifier. Owned executables were absent and the hidden desktop closed afterward.

See [observations](../../verification/selection-menu-observations.json) and [frame manifest](../../verification/selection-menu-frames.json). Raw frames remain private pending the separate global promotion contract. The other four commands have focused widget coverage only. This does not establish every toolbar arrangement, full framework localization, physical display scaling or actual clipboard behavior.

## 中文

七個預設文字選取指令會跟隨英文、粵語或雙語設定，並保留 Flutter 官方選單嘅操作、選取及關閉行為。明確提供名稱嘅自訂指令維持原有名稱。其他框架訊息及作業系統選單不包含喺呢次七個標籤改善內。

整合版本已建置，真正 800×600、兩倍雙語文字嘅選單顯示全選、剪下及複製。全選、Escape 關閉及 Backspace 清除均有實際畫面核對。沒有讀取安裝清單，亦沒有操作真實剪貼簿。其餘四項只有指定元件測試覆蓋。
