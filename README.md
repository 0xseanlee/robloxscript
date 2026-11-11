Use
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/0xseanlee/robloxscript/main/loader/loader.lua"))()
```
# This is 0xseanlee's roblox script place!!!
u can use my script for free!! 
## all script wont be Obfuscation
join my discord server -> # [Discord](https://discord.gg/mK9XWyV5Q2)

## 公開使用統計

統計頁原始碼在 `docs/`，以 GitHub Pages 發布。資料由既有 Cloudflare Worker + D1 提供，無須 Firebase、Google Analytics 或樹莓派持續開機。

### 收集與公開範圍

使用 `analytics/prepend.lua` 前置程式、透過 `/public/events` 收到的回報保存 Roblox UserId、PlaceId、腳本名稱、事件類型、隨機事件 ID 和伺服器接收時間。公開 API / 頁面顯示 **UserId、個人檔案連結、腳本、執行次數與時間**。不收集玩家名稱、裝置識別碼或裝置指紋；D1 不保存 IP。Cloudflare 仍會處理網路請求中繼資料。

同一 UserId 的執行次數累加；不同帳號各算一個帳號，不依裝置合併。帳號數不等於實際人數，無法判斷不同帳號是否屬於同一個人。停用回報後不會產生新紀錄：

```lua
getgenv().ROBLOX_ANALYTICS_DISABLED = true
```

前置程式可直接貼在 Lua 最前面，只需設定 `scriptName`。首次公開回報前會在執行器輸出資料說明。回報為非同步，失敗不影響後面的程式；公開 `script_started` 代表前置程式發出啟動回報，不保證後續程式載入或功能成功。此為客戶端自報資料，可被封鎖或偽造。

### 舊資料

舊匿名紀錄仍留在原本 `events` 表，**不連結至新 UserId、不還原、不公開**。原本 `analytics/client.lua` 及現有腳本的 `/events` 回報仍只保存匿名紀錄。公開前置程式使用另一個端點 `/public/events` 和獨立的 `public_events` 表，原有結尾回報不會重複計入公開統計；公開報表僅查這張表，因此原有匿名紀錄不會突然顯示玩家身分。

### 部署順序（Cloudflare 免費方案）

1. 對既有 D1 `roblox-analytics-db` 執行 `analytics/migrations/002-public-users.sql`，或以 Wrangler 執行：
   ```sh
   cd analytics
   npx wrangler d1 execute roblox-analytics-db --remote --file migrations/002-public-users.sql
   ```
2. 部署 `analytics/worker.mjs`：`npx wrangler deploy`。既有設定檔已綁定 D1；不更換資料庫、不啟用付費方案。
3. 檢查 `/health` 必須回傳 `version: public-users-v2`。未套用 migration 時新版健康檢查回傳 503。
4. GitHub 儲存庫 Settings → Pages → Source 選 **GitHub Actions**；執行 `Publish public analytics` 工作流程發布 `docs/`。若改用分支發布，選 `main` 的 `/docs`。
5. `docs/config.js` 設定公開 Worker URL，不放管理憑證。瀏覽器顯示 API 未部署時，不能視為統計已上線。

全新 D1 可執行 `analytics/schema.sql`；migration 可重複執行，不刪除任何舊資料。公開統計由實際部署新版 Worker 並在腳本前面加入 `analytics/prepend.lua` 後開始累積；本次不自動將前置程式插入任何遊戲檔案。

### 公開唯讀 API

- `GET /api/summary?days=30`：執行數、不重複帳號、重複使用帳號、每日數字。
- `GET /api/users?days=30&offset=0&limit=50&sort=recent`：帳號列表，可用 `user_id` 篩選完整 ID。
- `GET /api/events?days=30&user_id=123&limit=50`：單一帳號逐次執行紀錄；使用回傳的 `next_cursor` 繼續讀取。
- `days` 支援 `7`、`30`、`90`、`all`；可選 `script` 過濾腳本。日界與畫面時間使用台灣時間 UTC+8。
- `POST /public/events`：公開前置回報；原本 `POST /events` 繼續匿名化，兩者隔離。隨機事件 ID 相同時不重複寫入；同一帳號重跑產生不同 ID，因此正常累加。

沒有管理用刪改 API。寫入仍限制每帳號每分鐘 30 個事件、每日 UTC 10,000 個事件；達上限的回報不計數。此限制不能驗證 Roblox 身分，也不能阻止偽造大量帳號耗盡額度。

### 驗證

`node --test analytics/worker.test.mjs`（Node 22.13+）驗證 SQL 統計、同帳號累加、不同帳號分開、舊匿名資料隔離、分頁、輸入驗證與寫入上限。`lua analytics/client.test.lua` 驗證原有匿名回報，`lua analytics/prepend.test.lua` 驗證前置回報的停用、重跑與錯誤隔離。Roblox 執行器的實機測試仍需另外完成。
