<div align="center">
  <p><a href="README.md">English version</a></p>
  <h1>Countdown Float</h1>
  <p>把多個倒數或正計時器放在桌面上，專注工作時不用一直切換視窗。</p>
  <p>
    <a href="https://github.com/koru1130/FloatingCountdown">
      <img src="https://img.shields.io/badge/platform-macOS%2013%2B-161826?logo=apple&logoColor=white" alt="macOS 13+">
    </a>
    <a href="https://www.swift.org/">
      <img src="https://img.shields.io/badge/Swift-5.0-F05138?logo=swift&logoColor=white" alt="Swift 5">
    </a>
    <a href="https://developer.apple.com/xcode/">
      <img src="https://img.shields.io/badge/Xcode-16%2B-147EFB?logo=xcode&logoColor=white" alt="Xcode 16+">
    </a>
  </p>
</div>

<p align="center">
  <img src="Assets/Screenshots/countdown-float-ring.png" alt="Countdown Float Ring 模式" width="300">
  <img src="Assets/Screenshots/countdown-float-bar.png" alt="Countdown Float Bar 模式" width="312">
</p>

<p align="center">
  <img src="Assets/Screenshots/countdown-float-vscode.png" alt="Countdown Float 與 Xcode 同時執行" width="850">
</p>

<p align="center">
  <sub>目前截圖：Ring 模式、Bar 模式，以及與 Xcode 同時執行的 Countdown Float。</sub>
</p>

## 產品介紹

Countdown Float 是一個原生 macOS 選單列計時工具。它會在桌面上顯示輕量、可拖曳、置頂的浮動計時視窗，讓你在寫程式、閱讀、開會、做番茄鐘或等待某個時間點時，能隨時看見進度。

你可以同時執行多個計時器。每個計時器都有獨立的狀態、浮動視窗、編輯面板與完成流程，並可從同一個選單列清單新增及管理。隱藏其中一個浮動視窗只會收起該視窗，計時仍會在背景繼續。

### ADHD 與時間盲（time blindness）

對有 ADHD 相關時間盲經驗的人，或容易在高度專注時忘記時間的人，Countdown Float 提供持續且一眼可見的時間提示。把計時器放在桌面上，可以不用一直切換視窗查看時鐘，也更容易察覺已經經過或仍然剩餘的時間。這是一個生產力輔助工具，不是醫療或診斷工具。

> 目前專案以可由 Xcode 建置的 MVP 原始碼形式提供，也可從 v0.1.0 release 下載預先建置的 `.app`。

## 下載

[下載 Countdown Float v0.1.0](https://github.com/koru1130/FloatingCountdown/releases/download/v0.1.0/CountdownFloat-v0.1.0.app.zip) · [查看所有 releases](https://github.com/koru1130/FloatingCountdown/releases)

## 產品特色

- **多個獨立計時器**：可直接從選單列建立任意數量的計時器，並分別操作。
- **桌面浮動計時器**：無邊框、半透明、always-on-top，支援拖曳與跨 Spaces 顯示。
- **三種計時模式**：Duration 倒數、倒數到指定時間，或從 `00:00` 開始 Count up 正計時。
- **倒數顯示模式**：Duration 與 At a time 可使用 Bar 或 Ring；Count up 僅使用 Bar。
- **彈性進度基準**：可選擇 Full span 或 Start time，讓進度條／圓環代表更大的工作時段。
- **標籤**：可為每個計時器加上工作名稱、會議名稱或其他自訂文字，也能在計時中修改。
- **各自獨立操作**：可單獨顯示／隱藏、編輯、Pause、Resume、延長倒數、重設正計時或 Stop，不影響其他計時器。
- **精簡編輯面板**：顯示在對應計時器旁，提供 Label、Pause／Resume、個別浮窗尺寸，以及倒數的 Add 5 min 或正計時的 Reset；可按右上角 `×` 或移開焦點關閉。
- **Urgent 狀態**：剩餘 5 分鐘內會以高亮邊框、光暈與放大效果提醒。
- **倒數完成後顯示超時**：倒數歸零後顯示 `+mm:ss`，方便知道超時多久。
- **浮窗尺寸**：可從各自的編輯面板調整，或將滑鼠移到浮窗上滾動；尺寸範圍為 75%–150%，並會分別保存。
- **系統通知**：完成時發送 macOS 通知，通知內可直接選擇 `Add 5 min` 或 `End`。
- **無第三方依賴**：使用 SwiftUI、AppKit、Combine 與 UserNotifications 建置。

## 畫面一覽

| 畫面 | 說明 |
| --- | --- |
| **Float — Bar** | 顯示倒數或正計時、水平進度條與結束時間／標籤。 |
| **Float — Ring** | 以圓環呈現倒數進度，適合更緊湊的桌面顯示；Count up 不使用 Ring。 |
| **New timer panel** | 設定 Duration、At a time 或 Count up，以及該模式適用的選項。 |
| **Edit panel** | 顯示在單一浮窗旁，提供即時更新的 Label、Pause／Resume、75%–150% 尺寸控制、倒數的 Add 5 min 或正計時的 Reset，以及右上角 `×`。 |
| **Menu bar extra** | 顯示一個代表計時器；有更多計時器時加上 `+N`，沒有計時器時顯示 `New`。 |
| **Countdown menu** | 列出所有計時器，提供 New、顯示／隱藏、編輯、暫停／繼續、延長、停止與退出。停止計時器不會關閉選單。 |
| **Completion toast / notification** | 倒數完成後顯示超時狀態，並提供延長或結束操作。 |

上方 Ring 與 Bar 截圖呈現目前的浮窗介面，Xcode 截圖則展示 Countdown Float 與原始碼同時執行的畫面。完整的 UI states 總覽位於 [`DesignFromClaude/handoff/ui-states.png`](DesignFromClaude/handoff/ui-states.png)，它是設計參考圖，不是模擬桌面截圖。

## 系統需求

- macOS 13.0 或更新版本
- Xcode 16 或更新版本
- Swift 5 language mode
- 不需要額外安裝套件或第三方 dependency

## 安裝與執行

### 使用 Xcode

```sh
git clone https://github.com/koru1130/FloatingCountdown.git
cd FloatingCountdown
open CountdownFloat.xcodeproj
```

在 Xcode 中選擇 `CountdownFloat` scheme，按下 Run 即可。這是一個 menu-bar app，啟動後不會在 Dock 顯示一般應用程式圖示；每次啟動時，New countdown 面板會在目前螢幕的右上方開啟。

### 使用命令列建置

```sh
xcodebuild \
  -project CountdownFloat.xcodeproj \
  -scheme CountdownFloat \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build \
  CODE_SIGNING_ALLOWED=NO
```

也可以使用專案內的腳本建置並啟動：

```sh
./script/build_and_run.sh
```

`script/build_and_run.sh` 預設會建置 Debug app 後開啟；它會先關閉同名的執行中程序。可用 `--verify` 確認 app 是否成功啟動，也可以用 `--telemetry` 查看 app 的 runtime log。

## 使用方式

1. 點擊選單列上的 Countdown Float 項目開啟計時器清單，再按 `New`；app 啟動時也會自動打開 New countdown 面板。
2. 選擇計時模式：
   - **Duration**：輸入 1–600 分鐘，可直接選擇 5、15、25 或 60 分鐘。
   - **At a time**：輸入 `HH:mm` 目標時間；已經過去的時間會視為隔天。
   - **Count up**：從 `00:00` 開始正計時，直到手動停止。
3. 可視需要填入 Label；Duration 另可設定 Full span，At a time 另可設定 Start time。
4. 倒數模式可選擇 `Bar` 或 `Ring`；Count up 固定使用 Bar。按下 `Start` 開始。
5. 重複按 `New` 即可建立多個互相獨立的計時器。可拖曳各浮窗到想要的位置，並在浮窗上滾動來放大或縮小。
6. 將滑鼠移到浮窗上，可看到編輯（`…`）與隱藏（`×`）按鈕。精簡編輯面板會顯示在該浮窗旁；Label 修改會立即套用，`−`／`+` 可在 75%–150% 間只縮放該浮窗。倒數編輯器提供 Add 5 min，正計時編輯器則提供 Reset 回到 `00:00`。按面板的 `×` 或移開焦點即可關閉。
7. 每個選單列項目都能獨立顯示／隱藏、編輯、Pause／Resume、為倒數 Add 5 min，或 Stop。停止一個計時器會移除該列，但不會關閉選單。
8. 倒數完成時，該浮窗會顯示超時時間，並出現專屬的完成通知。若 macOS 詢問通知權限，請選擇允許，才能收到系統通知與通知內的快速操作。

### 時間與進度規則

- 一般時間格式為 `mm:ss`；超過一小時時使用 `h:mm:ss`。
- 倒數完成後使用 `+mm:ss` 或 `+h:mm:ss` 持續顯示超時時間。
- Count up 從 `00:00` 開始，沒有目標時間與完成通知，只使用 Bar，並在編輯面板以 Reset 取代 Add 5 min。
- 預設 Urgent threshold 為剩餘 5 分鐘。
- `Add 5 min` 會增加 300 秒，同時延長進度的總跨度。
- 隱藏浮窗只會隱藏該視窗，不會暫停計時；選單列與通知仍會正常更新。
- Bar 模式在完成後歸零；Ring 模式在完成後呈現完整圓環。

## 操作狀態

```text
New ── Start countdown ──▶ Running ◀── Pause / Resume ──▶ Paused
                              │
                              ├── Add 5 min ───────────▶ Running
                              └── 到達零點 ────────────▶ Done / overtime

New ── Start Count up ───▶ Running upward ◀── Pause / Resume ──▶ Paused
                                  ▲
                                  └── Reset 回到 00:00 ────────┘

任何進行中的計時器 ── Stop / End ──▶ 從清單移除
```

## 專案結構

```text
FloatingCountdown/
├── CountdownFloat.xcodeproj/
├── CountdownFloat/
│   ├── App/              # SwiftUI App 與 AppKit coordinator
│   ├── Model/            # 計時器集合／狀態、時間計算、浮窗幾何與尺寸設定
│   ├── Panels/           # Float、編輯與完成提示的 NSPanel controller
│   ├── Services/         # macOS UserNotifications 整合
│   ├── Views/            # SwiftUI 浮窗、設定面板、選單與通知 UI
│   └── Info.plist
├── CountdownFloatTests/  # Store、collection、幾何與尺寸設定測試
├── DesignFromClaude/     # UI states 與設計交接文件
└── script/               # 本地建置／啟動腳本
```

### 核心元件

| 元件 | 職責 |
| --- | --- |
| `CountdownCollection` | 發布選單列清單中所有進行中的計時器 store。 |
| `CountdownStore` | 以 `@MainActor` 管理單一倒數或正計時器的生命週期、時間格式、進度、Urgent 與完成事件。 |
| `AppDelegate` | 管理各計時器 session，並協調 menu-bar item、計時器清單、面板與通知 callback。 |
| `SetupPanelController` | 顯示 New timer 面板，或在所選計時器旁顯示精簡編輯面板；編輯時支援失焦關閉。 |
| `FloatPanelController` | 管理無邊框置頂浮窗、拖曳位置、跨螢幕 clamping 與尺寸縮放。 |
| `FloatView` | 呈現 Bar／Ring、狀態樣式、hover controls 與完成脈動效果。 |
| `CompletionPanelController` | 為到達零點的計時器顯示完成提示。 |
| `NotificationManager` | 請求通知權限、發送完成通知，以及處理 `Add 5 min`／`End` action。 |
| `FloatGeometry` / `FloatScaleSettings` | 提供可測試的視窗幾何計算與 75%–150% 尺寸偏好。 |

每個進行中的計時器都擁有獨立的 `CountdownStore`、浮窗、編輯面板與完成面板。各項操作會使用 store 的 UUID 定位，因此選單與通知只會更新正確的計時器，不影響其他計時器。

## 建置與測試

執行完整 unit test：

```sh
xcodebuild \
  -project CountdownFloat.xcodeproj \
  -scheme CountdownFloat \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  test \
  CODE_SIGNING_ALLOWED=NO
```

測試涵蓋：

- `CountdownStore` 的倒數與 Count up 啟動、Pause、Resume、完成、超時累計、Add 5 min、Stop 與 Reset 行為。
- `CountdownCollection` 對多個獨立計時器 store 的管理行為。
- Duration 與 At a time 的日期解析，包括「已過去時間視為明天」的規則。
- `mm:ss`、`h:mm:ss` 與 `+mm:ss` 格式化。
- 浮窗初始位置、螢幕邊界 clamping、縮放 anchor 與尺寸設定的 persistence。

`CountdownStore` 支援注入 `DateProvider`，因此時間相關測試不需要真的等待倒數結束。

## 資料、權限與隱私

- 不需要帳號，也沒有網路請求或遠端服務。
- 計時器狀態只存在於目前 app process；重新啟動 app 後不會恢復進行中的計時器。
- 各浮窗位置與顯示尺寸會使用 `UserDefaults` 儲存在本機，方便下次啟動時還原。
- 系統通知只在倒數完成時使用；通知權限由 macOS 管理，使用者可以隨時在系統設定中關閉。

## 設計文件

設計與實作對照資料位於 `DesignFromClaude/`：

- [UI states 總覽](DesignFromClaude/handoff/ui-states.png)
- [設計交接說明](DesignFromClaude/handoff/README.md)
- [完整 design spec](DesignFromClaude/handoff/design-spec.md)
- [互動式參考頁](DesignFromClaude/Countdown%20Float%20Reference.dc.html)

## 已知限制

- 目前沒有提供簽章、打包或自動更新流程。
- 目前不保存進行中的計時器；退出 app 後需要重新設定。
- 通知功能依賴 macOS 的通知權限與系統設定。

## Contributing

歡迎提交 issue 或 pull request。建議在提交前：

1. 先描述問題或想改善的使用情境。
2. 對功能變更補上對應的 unit test。
3. 確認 `xcodebuild ... test CODE_SIGNING_ALLOWED=NO` 可以通過。
4. 若修改 UI，同步更新 `DesignFromClaude/` 中的說明或預覽素材。

## License

目前 repository 尚未附上 `LICENSE` 檔案。若要重新散布、商用或整合到其他專案，請先與作者確認授權方式。
