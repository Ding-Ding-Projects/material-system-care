# Minimum-size keyboard navigation · 最小視窗鍵盤操作

The rebuilt background sender was exercised against the real Services, Scheduled tasks and Processes workspaces at an 800 × 600 client area, dark theme, English/Cantonese together and text scale 2. Tab traversal, Page Down movement and input into the lower search fields were observed. No host inventory was collected.

已在真正建置嘅服務、排程工作及程序工作區測試背景鍵盤操作：視窗內容範圍為 800 × 600、深色主題、英語及廣東話雙語、文字比例 2。已觀察到 Tab 移動焦點、Page Down 捲動，以及下方搜尋欄輸入；沒有收集本機清單。

## What changed · 修正內容

No product scrolling change was needed. The input transport omitted the extended-key bit when a keyboard layout returned a plain scan code for Page Down. The sender now handles dedicated navigation keys explicitly. The initial mocked test assumed an E0 prefix and missed this case; a prefix-free regression now fails the old sender and passes the corrected one. Four focused sender tests pass.

產品捲動邏輯毋須修改。鍵盤配置回傳普通掃描碼時，傳送層遺漏 Page Down 嘅延伸鍵位元；現時會明確處理專用導覽鍵。原先模擬測試假設有 E0 前綴，漏咗呢個情況；新回歸測試確認舊版本失敗、修正版本通過。四項指定傳送測試通過。

## Evidence limits · 證據範圍

[The observation manifest](../../captures/keyboard-navigation.json) binds all nine unedited PNGs to the source, executable, build receipt, input records and owned teardown. These are painted Flutter frames, not native-compositor captures. Exact frame times were not emitted and are not inferred from filenames or file timestamps. The generic time-stamped evidence contract is not claimed. This does not finish the full theme, scale, popup, populated-state, accessibility or motion matrix.

[觀察清單](../../captures/keyboard-navigation.json)記錄九張未經修改 PNG 嘅來源版本、執行檔、建置收據、輸入記錄及專屬程序清理。圖片由 Flutter 繪製輸出，並非原生合成器擷取。沒有輸出每張畫面嘅準確時間，亦不會靠檔名或檔案時間推測。本次不聲稱符合通用時間戳證據規格，完整主題、比例、彈出選單、有資料狀態、無障礙及動態矩陣仍未完成。

## Services · 服務

### Initial focus · 初始焦點

![Services · 服務: Initial focus · 初始焦點, bilingual dark theme, 800 by 600 and doubled text](../../captures/services-keyboard-initial-focus.png)

### After Page Down · Page Down 之後

![Services · 服務: After Page Down · Page Down 之後, bilingual dark theme, 800 by 600 and doubled text](../../captures/services-keyboard-page-down.png)

### Keyboard input · 鍵盤輸入

![Services · 服務: Keyboard input · 鍵盤輸入, bilingual dark theme, 800 by 600 and doubled text](../../captures/services-keyboard-search-input.png)

## Scheduled tasks · 排程工作

### Initial focus · 初始焦點

![Scheduled tasks · 排程工作: Initial focus · 初始焦點, bilingual dark theme, 800 by 600 and doubled text](../../captures/scheduled-tasks-keyboard-initial-focus.png)

### After Page Down · Page Down 之後

![Scheduled tasks · 排程工作: After Page Down · Page Down 之後, bilingual dark theme, 800 by 600 and doubled text](../../captures/scheduled-tasks-keyboard-page-down.png)

### Keyboard input · 鍵盤輸入

![Scheduled tasks · 排程工作: Keyboard input · 鍵盤輸入, bilingual dark theme, 800 by 600 and doubled text](../../captures/scheduled-tasks-keyboard-search-input.png)

## Processes · 程序

### Initial focus · 初始焦點

![Processes · 程序: Initial focus · 初始焦點, bilingual dark theme, 800 by 600 and doubled text](../../captures/processes-keyboard-initial-focus.png)

### After Page Down · Page Down 之後

![Processes · 程序: After Page Down · Page Down 之後, bilingual dark theme, 800 by 600 and doubled text](../../captures/processes-keyboard-page-down.png)

### Keyboard input · 鍵盤輸入

![Processes · 程序: Keyboard input · 鍵盤輸入, bilingual dark theme, 800 by 600 and doubled text](../../captures/processes-keyboard-search-input.png)
