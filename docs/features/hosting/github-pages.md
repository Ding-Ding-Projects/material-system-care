# Public documentation deployment

## Complete articles and bilingual gallery

The website has an internal complete-article reader at `#/articles` and a forty-image bilingual gallery at `#/gallery`. The build indexes tracked Markdown, excluding agent instructions and hosting administration files, preserves full article content, sanitizes active HTML, and rewrites relative article links to internal routes. It also emits a prerendered HTML copy of every article. Local documentation images and evidence files are copied from tracked public sources, never private capture directories.

GitHub source links are optional references, not substitutes for reading articles. The wiki Git endpoint currently reports that the repository is unavailable; no wiki import is claimed. If a separate wiki becomes available, its complete reviewed content must be mirrored into this website before claiming synchronization.

The gallery contains only bilingual initial desktop viewports. Its complete inventory, source binding, limitations and original image links are in `SCREENSHOTS.md` and `docs/captures/gallery.json`. A thumbnail or gallery image does not establish complete interaction, accessibility, physical display scaling or absence of layout defects elsewhere.

## 完整文章及雙語圖庫

網站內提供完整文章閱讀器及四十張雙語畫面圖庫。建置會保留已追蹤 Markdown 的完整內容、移除可執行 HTML，並將內部文章連結留在網站內，亦輸出預先呈現的 HTML。GitHub 只作可選原始碼參考，不能代替文章內容。Wiki 端點目前未能使用，沒有宣稱已同步。圖庫屬初始待命畫面，並非完整操作或全部版面驗證。

## GitHub Pages hosting

The public documentation is deployed from `website/dist` to https://ding-ding-projects.github.io/material-system-care/ by `.github/workflows/pages.yml`. The workflow invokes the root `build.bat /s --target=site` entrypoint, uses the existing pinned toolchain bootstrap, uploads the static output, and deploys with the Pages environment. It runs no tests or lint.

Relative Vite assets, metadata fetches, and the logo resolve beneath the project path. The canonical URL, sitemap, and crawler declaration use the GitHub Pages URL. The previous external deployment is historical and does not satisfy the hosting requirement. Verify the live home page, asset responses, deployment commit, and repository homepage before claiming delivery. Browser screenshots and the full desktop release remain separately unverified.
