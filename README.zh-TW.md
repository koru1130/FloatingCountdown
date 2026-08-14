<div align="center">
  <p><a href="README.md">English version</a></p>
  <h1>Countdown Float</h1>
  <p>把倒數時間放在桌面上，專注工作時不用一直切換視窗。</p>
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

Countdown Float 是一個原生 macOS 選單列倒數工具。它會在桌面上顯示一個輕量、可拖曳、置頂的浮動倒數視窗，讓你在寫程式、閱讀、開會、做番茄鐘或等待某個時間點時，能隨時看見進度。

倒數由同一個共享狀態管理，浮動視窗、選單列項目、設定面板與完成通知會保持同步。即使暫時隱藏浮動視窗，倒數仍會繼續執行。

### ADHD 與時間盲（time blindness）

對有 ADHD 相關時間盲經驗的人，或容易在高度專注時忘記時間的人，Countdown Float 提供持續且一眼可見的剩餘時間提示。把倒數放在桌面上，可以不用一直切換視窗查看時鐘，也更容易察覺時間正在流逝。這是一個生產力輔助工具，不是醫療或診斷工具。

> 目前專案以可由 Xcode 建置的 MVP 原始碼形式提供，也可從 v0.1.0 release 下載預先建置的 `.app`。

## 下載

[下載 Countdown Float v0.1.0](https://github.com/koru1130/FloatingCountdown/releases/download/v0.1.0/CountdownFloat-v0.1.0.app.zip) · [查看所有 releases](https://github.com/koru1130/FloatingCountdown/releases)

## 產品特色

- **桌面浮動倒數**：無邊框、半透明、always-on-top，支援拖曳與跨 Spaces 顯示。
- **兩種視覺模式**：Bar 進度條與 Ring 圓環進度。
- **兩種設定方式**：輸入倒數分鐘數，或設定一個目標時間。
- **彈性進度基準**：可選擇 Full span 或 Start time，讓進度條／圓環代表更大的工作時段。
- **標籤**：可為倒數加上工作名稱、會議名稱或其他自訂文字。
- **完整生命週期**：Start、Pause、Resume、Add 5 min、Stop，以及完成後的 End。
- **Urgent 狀態**：剩餘 5 分鐘內會以高亮邊框、光暈與放大效果提醒。
- **完成後繼續計時**：倒數歸零後顯示 `+mm:ss`，方便知道超時多久。
- **選單列控制**：從選單列查看剩餘時間、顯示／隱藏浮動視窗、編輯倒數與調整浮窗大小。
- **系統通知**：完成時發送 macOS 通知，通知內可直接選擇 `Add 5 min` 或 `End`。
- **無第三方依賴**：使用 SwiftUI、AppKit、Combine 與 UserNotifications 建置。

## 畫面一覽

| 畫面 | 說明 |
| --- | --- |
| **Float — Bar** | 顯示時間、水平進度條與結束時間／標籤。 |
| **Float — Ring** | 以圓環呈現剩餘進度，適合更緊湊的桌面顯示。 |
| **Setup panel** | 設定 Duration 或 At a time、Full span、Start time、標籤與浮窗樣式。 |
| **Menu bar extra** | 顯示目前剩餘時間；尚未設定時顯示 `Set`。 |
| **Countdown menu** | 控制浮窗顯示、編輯、暫停、延長、停止與退出。 |
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

在 Xcode 中選擇 `CountdownFloat` scheme，按下 Run 即可。這是一個 menu-bar app，啟動後不會在 Dock 顯示一般應用程式圖示；第一次啟動時，設定面板會從選單列項目旁邊打開。

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

1. 點擊選單列上的 Countdown Float 項目，開啟 `Set countdown` 設定面板。
2. 選擇輸入方式：
   - **Duration**：輸入 1–600 分鐘，可直接選擇 5、15、25 或 60 分鐘。
   - **At a time**：輸入 `HH:mm` 目標時間；已經過去的時間會視為隔天。
3. 視需要填入 Full span、Start time 與 Label。
4. 選擇 `Bar` 或 `Ring`，按下 `Start`。
5. 拖曳浮窗到想要的位置；滑鼠移到浮窗上方即可看見重新設定與隱藏按鈕。
6. 點擊選單列項目可開啟操作選單，包括 Pause／Resume、Add 5 min、Float size 與 Stop。
7. 倒數完成時，浮窗會進入 counting-up 狀態並顯示完成通知。若 macOS 詢問通知權限，請選擇允許，才能收到系統通知與通知內的快速操作。

### 時間與進度規則

- 一般時間格式為 `mm:ss`；超過一小時時使用 `h:mm:ss`。
- 倒數完成後使用 `+mm:ss` 或 `+h:mm:ss` 持續顯示超時時間。
- 預設 Urgent threshold 為剩餘 5 分鐘。
- `Add 5 min` 會增加 300 秒，同時延長進度的總跨度。
- 隱藏浮窗只會隱藏視窗，不會暫停倒數；選單列與通知仍會正常更新。
- Bar 模式在完成後歸零；Ring 模式在完成後呈現完整圓環。

## 操作狀態

```text
Idle ── Start ──▶ Running ── Pause ──▶ Paused
  ▲                 │  ▲                │
  │                 │  └── Resume ──────┘
  │                 │
  │                 ├── Add 5 min ──▶ Running
  │                 │
  │                 └── 到達零點 ──▶ Done / counting up
  │                                      │
  └──────────── Stop / End / Reset ◀────┘
```

## 專案結構

```text
FloatingCountdown/
├── CountdownFloat.xcodeproj/
├── CountdownFloat/
│   ├── App/              # SwiftUI App 與 AppKit coordinator
│   ├── Model/            # 倒數狀態、時間計算、浮窗幾何與尺寸設定
│   ├── Panels/           # Always-on-top float 與完成提示的 NSPanel
│   ├── Services/         # macOS UserNotifications 整合
│   ├── Views/            # SwiftUI 浮窗、設定面板、選單與通知 UI
│   └── Info.plist
├── CountdownFloatTests/  # CountdownStore、幾何與尺寸設定測試
├── DesignFromClaude/     # UI states 與設計交接文件
└── script/               # 本地建置／啟動腳本
```

### 核心元件

| 元件 | 職責 |
| --- | --- |
| `CountdownStore` | 以 `@MainActor` 管理倒數生命週期、時間格式、進度、Urgent 與完成事件。 |
| `AppDelegate` | 協調 menu-bar item、popover、浮窗、完成提示與通知 callback。 |
| `FloatPanelController` | 管理無邊框置頂浮窗、拖曳位置、跨螢幕 clamping 與尺寸縮放。 |
| `FloatView` | 呈現 Bar／Ring、狀態樣式、hover controls 與完成脈動效果。 |
| `NotificationManager` | 請求通知權限、發送完成通知，以及處理 `Add 5 min`／`End` action。 |
| `FloatGeometry` / `FloatScaleSettings` | 提供可測試的視窗幾何計算與 75%–150% 尺寸偏好。 |

整個 app 只使用一個共享的 `CountdownStore`。這讓隱藏浮窗、從選單列操作或從通知延長倒數時，不會產生不同步的倒數副本。

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

- `CountdownStore` 的 Start、Pause、Resume、完成、超時累計、Add 5 min、Stop 與 Reset。
- Duration 與 At a time 的日期解析，包括「已過去時間視為明天」的規則。
- `mm:ss`、`h:mm:ss` 與 `+mm:ss` 格式化。
- 浮窗初始位置、螢幕邊界 clamping、縮放 anchor 與尺寸設定的 persistence。

`CountdownStore` 支援注入 `DateProvider`，因此時間相關測試不需要真的等待倒數結束。

## 資料、權限與隱私

- 不需要帳號，也沒有網路請求或遠端服務。
- 倒數狀態只存在於目前 app process；目前不會在重新啟動 app 後恢復進行中的倒數。
- 浮窗位置與浮窗尺寸會使用 `UserDefaults` 儲存在本機，方便下次啟動時還原。
- 系統通知只在倒數完成時使用；通知權限由 macOS 管理，使用者可以隨時在系統設定中關閉。

## 設計文件

設計與實作對照資料位於 `DesignFromClaude/`：

- [UI states 總覽](DesignFromClaude/handoff/ui-states.png)
- [設計交接說明](DesignFromClaude/handoff/README.md)
- [完整 design spec](DesignFromClaude/handoff/design-spec.md)
- [互動式參考頁](DesignFromClaude/Countdown%20Float%20Reference.dc.html)

## 已知限制

- 目前沒有提供簽章、打包或自動更新流程。
- 目前不保存進行中的倒數；退出 app 後需要重新設定。
- 通知功能依賴 macOS 的通知權限與系統設定。

## Contributing

歡迎提交 issue 或 pull request。建議在提交前：

1. 先描述問題或想改善的使用情境。
2. 對功能變更補上對應的 unit test。
3. 確認 `xcodebuild ... test CODE_SIGNING_ALLOWED=NO` 可以通過。
4. 若修改 UI，同步更新 `DesignFromClaude/` 中的說明或預覽素材。

## License

目前 repository 尚未附上 `LICENSE` 檔案。若要重新散布、商用或整合到其他專案，請先與作者確認授權方式。
