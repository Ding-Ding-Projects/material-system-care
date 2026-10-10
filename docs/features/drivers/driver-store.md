# Driver store review

The Drivers workspace explicitly collects `drivers.list` and presents Windows third-party driver-store packages. It never polls automatically and provides no install, update, export or removal action. Select **Collect driver inventory** for an initial collection or a refresh. Expand a package to select its published name, original file name, provider, device class, reported version and reported signer.

The package's published `oem<number>.inf` name is its identity. Display metadata is never interpreted as a command or identity. Missing metadata is labelled **Not reported**. Signer metadata is reported by Windows, not independently validated by this workspace. A listed signer does not prove current trust, compatibility or update eligibility. Version strings are displayed literally; the workspace does not compare versions or recommend updates. Inbox drivers, device health and an online catalogue are outside this inventory.

The receipt timestamp is when the desktop accepted the response, not when a driver was measured or installed. A refresh clears previous records immediately. Failed collection or invalid data displays a fixed retry message without reflecting exception text. A pending collection disables duplicate submission. Replies after disposal are ignored.

## Validation and interaction

The desktop requires the exact `Windows driver store` source, a boolean false `onlineCatalogueAvailable`, and at most 25,000 records. Every record requires a unique case-insensitive published package name matching `oem[0-9]+.inf`, with a 64-character limit. The five nullable metadata fields must be present, strings no longer than 4,096 characters or null, and free of control and bidirectional formatting characters. Malformed records reject the entire response rather than disappearing silently. Empty and whitespace-only optional metadata is shown as unavailable.

Cards use standard Material expansion controls and selectable text. Repeated Page Down and Page Up retain page focus while scrolling. Text-selection editing keys retain their normal behavior. Normal paging animates for 200 milliseconds; reduced motion uses immediate scrolling and zero-duration expansion in both directions. English, Cantonese and bilingual preferences apply to labels. No search field is introduced by this workspace.

`--driver-inventory` opens this workspace directly. Existing `--capture-*` options use isolated preferences and require exactly one workspace destination, as on the other inspection routes. Captures do not initiate collection.

## Verification boundary

Focused widget tests exercise strict parser rejection, exact metadata, empty inventory, explicit collection, stale-result removal, pending/disposed responses, page focus, normal and reduced motion, and an 800 by 600 bilingual layout at 200% text size. They use synthetic records and a mocked engine boundary. A desktop build checks compilation. Neither proves a live PnPUtil response, signature trust, driver changes or full capability parity. Capability ledger states are not promoted by these source checks.

Integrated source `83f6503d88f31fce43bdbc25477599bd3989839c` passed its exact root desktop build on the second attempt after an MSBuild task-host initialization failure. The real read-only collection returned 27 packages at 1280 × 1000 and 800 × 600 with doubled bilingual text, dark theme and reduced motion. First-package metadata, signer limitations, receipt time, repeated paging and reverse movement were inspected. Fourteen selected frames and nineteen supporting hashes passed the narrow source/bundle/two-hook verifier. Owned processes and desktops were closed. Populated records remain private; the published idle frame has a separate version-2 promotion receipt. Other appearance states, full keyboard order, physical DPI and unavailable/malformed runtime responses remain unverified.

中文：呢個頁面只會喺按鈕確認後讀取第三方驅動程式清單，唔會安裝、移除或更新。實際整合版本喺正常尺寸同 800 × 600 兩倍雙語文字都回報 27 個套件，已檢查詳細資料、簽署限制、接收時間及上下翻頁。十四張選定畫面同十九項佐證已核對來源；本機資料保持私人，公開嘅只係未收集資料之前嘅待命畫面。完整外觀、實體 DPI 及所有異常狀態仍未完成。
