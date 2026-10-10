# Text selection commands

Material System Care uses Flutter's standard Material text-selection toolbar. The seven default commands, Copy, Cut, Paste, Select all, Look Up, Search Web and Share, follow the current English, Cantonese or bilingual wording preference.

The application supplies the current language and validated local wording mapping to a Material localization delegate. An immutable snapshot prevents later mutation of the input map from changing an already-loaded value. Replacing or clearing the wording preference reloads dependent toolbars. The delegate relies on the existing settings validator; it is not an independent arbitrary-settings sanitizer.

Flutter still decides which commands are available and owns selection, callbacks, clipboard access, placement and dismissal. Explicitly labelled custom commands retain their own labels. Other inherited Material messages and operating-system menus are not covered by this seven-label change.

## Verification

The source candidate `638a56000ad88b429c4216c63f192468000e4d8c` passed 21 focused checks and its exact root desktop build. Tests exercise all seven labels in three language modes, preference snapshot and reload behavior, an actual Apps search-field toolbar at 800×600 with doubled text, a language change while open, reopening, standard Copy and Select all callbacks, and preservation of an explicit custom label. Clipboard calls are mocked. Two independent source reviews found no concrete defect in this bounded change.

The integrated build and real hidden-desktop popup inspection remain pending. This does not establish every toolbar arrangement, full framework localization, physical display scaling or actual clipboard behavior.

## 中文

七個預設文字選取指令會跟隨英文、粵語或雙語設定，並保留 Flutter 官方選單嘅操作、選取及關閉行為。明確提供名稱嘅自訂指令維持原有名稱。其他框架訊息及作業系統選單不包含喺呢次七個標籤改善內。

指定元件測試及候選版本建置已通過，實際隱藏桌面選單檢查仍待完成。剪貼簿測試使用模擬通道，唔代表已操作真實剪貼簿。
