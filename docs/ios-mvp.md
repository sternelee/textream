# Textream iOS MVP

## Goal

Build an **independent iOS teleprompter app** focused on the core reading experience, not macOS-style floating overlays.

Target users:
- iPhone creators recording short videos / talking-head clips
- iPad users rehearsing talks or reading scripts hands-free
- users who need a clean fullscreen teleprompter with speech-aware progression

---

## Product definition

### In scope for MVP

1. **Script editing**
   - Create / edit script text
   - Multi-page script model
   - Switch current page
   - Mark read pages

2. **Reader mode**
   - Fullscreen teleprompter view
   - Large, high-contrast text
   - Tap a word to jump progress
   - Manual pause / resume
   - Previous / next page

3. **Reading modes**
   - **Classic**: fixed-speed auto-scroll
   - **Voice-Activated**: scroll only while user is speaking
   - **Word Tracking**: speech recognition advances the read position word-by-word

4. **Basic customization**
   - Font size
   - Font family
   - Highlight color
   - Scroll speed
   - Speech locale

5. **Persistence**
   - Save/load `.textream` document format
   - Recent local drafts (phase 2 if needed)

### Explicitly out of scope for MVP

- macOS-style floating notch overlay
- cross-app overlay / always-on-top behavior
- browser remote view
- director mode
- external display / mirror mode
- AI script generation
- PPTX import
- camera / recording / livestream integration
- share extension

---

## MVP success criteria

The MVP is successful if a user can:
1. open the iOS app,
2. paste or type a script,
3. choose a reading mode,
4. start a fullscreen teleprompter,
5. read using auto-scroll or speech-aware progression,
6. pause, jump, and move between pages without losing context.

---

## Core capability mapping from current macOS code

### Reuse directly / mostly directly
- text splitting: `splitTextIntoWords`
- speech/text matching algorithms from `SpeechRecognizer`
  - `charLevelMatch`
  - `wordLevelMatch`
  - fuzzy match / edit distance
  - confidence gating
- page navigation ideas from `TextreamService`

### Reuse with adaptation
- `SpeechScrollView` / word flow rendering ideas
- `ListeningMode` and presentation settings
- reading progress model

### Replace completely on iOS
- `NotchOverlayController`
- `NSPanel` overlay logic
- AppKit file panels
- macOS menu/services behavior
- multi-display notch/floating logic

---

## Information architecture

```text
App
├── Home / Script Editor
│   ├── current script title
│   ├── page list
│   ├── page editor
│   ├── mode picker
│   ├── start reading
│   └── settings entry
├── Reader Screen
│   ├── top bar
│   │   ├── close
│   │   ├── page index
│   │   └── mode badge
│   ├── teleprompter text viewport
│   │   ├── read text dimmed
│   │   ├── active word highlighted
│   │   └── tap-to-jump
│   └── bottom controls
│       ├── progress
│       ├── waveform / mic state
│       ├── play/pause
│       ├── mic toggle
│       ├── prev page
│       └── next page
└── Settings
    ├── reading mode defaults
    ├── font size / family
    ├── colors
    ├── speech locale
    └── scroll speed
```

---

## Page structure diagram

### 1) Home / Script Editor

```text
┌──────────────────────────────────────┐
│ Textream                            │
│ [Settings]                          │
├──────────────────────────────────────┤
│ Script title / Untitled             │
│                                      │
│ Pages                               │
│ ┌────┐ ┌────┐ ┌────┐ [+]            │
│ │ 1  │ │ 2  │ │ 3  │                │
│ └────┘ └────┘ └────┘                │
│                                      │
│ Mode: [Classic v]                   │
│                                      │
│ ┌──────────────────────────────────┐ │
│ │ editable script text             │ │
│ │ ...                              │ │
│ └──────────────────────────────────┘ │
│                                      │
│ [Start Reading]                      │
└──────────────────────────────────────┘
```

### 2) Reader Screen

```text
┌──────────────────────────────────────┐
│ [Close]              Page 1/3  Word │
├──────────────────────────────────────┤
│                                      │
│      unread text                     │
│      unread text                     │
│      current word                    │
│      read text                       │
│      read text                       │
│                                      │
├──────────────────────────────────────┤
│ progress ███████░░░░                 │
│ waveform ▂▃▅▆▃▂   mic:on             │
│ [Prev] [Pause] [Mic] [Next]          │
└──────────────────────────────────────┘
```

### 3) Settings

```text
┌──────────────────────────────────────┐
│ Settings                             │
├──────────────────────────────────────┤
│ Default mode                         │
│ Font family                          │
│ Font size                            │
│ Highlight color                      │
│ Scroll speed                         │
│ Speech locale                        │
└──────────────────────────────────────┘
```

---

## State model

### Script model
- `title`
- `pages: [String]`
- `currentPageIndex`
- `readPages: Set<Int>`
- `currentPageText`
- `hasNextPage`

### Reading session model
- `mode: TeleprompterMode`
- `isRunning`
- `isPaused`
- `wordProgress: Double`
- `recognizedCharCount: Int`
- `audioLevels: [Double]`
- `isListening`
- `lastSpokenText`

### Settings model
- `fontSizePreset`
- `fontFamilyPreset`
- `highlightColorPreset`
- `scrollSpeed`
- `speechLocale`

---

## Implementation sequence

### Phase 1 — shared core scaffolding
1. Extract platform-neutral script/page model
2. Extract reading session / progress model
3. Extract reusable text-splitting helpers
4. Extract reusable speech matching engine

### Phase 2 — iOS app shell
5. Add iOS target
6. Build Home / Script Editor screen
7. Build Reader screen shell
8. Build Settings screen shell

### Phase 3 — MVP reading features
9. Implement Classic mode
10. Implement Voice-Activated mode
11. Implement Word Tracking mode
12. Add page navigation + tap-to-jump
13. Add local save/load

---

## Recommended first engineering slice

Because the current Xcode project is **macOS-only** (`SDKROOT = macosx`, `MACOSX_DEPLOYMENT_TARGET = 15.7`), the safest first step is:

1. create a **shared platform-neutral core**,
2. move reusable reading logic there,
3. then add the iOS target on top of that core.

This avoids mixing UIKit code into the current macOS build too early.

---

## Current implementation progress

> 最后更新：2026-05-13

### 已完成的阶段

#### Phase 1 — 共享核心 ✅
- `TeleprompterCore.swift`：跨平台脚本模型 `ScriptDocument`、阅读会话 `ReadingSessionState`、阅读模式枚举
- `TextSegmentation.swift`：CJK 感知分词 + annotation 判断
- `ScriptDocumentStore.swift`：`.textream` 编解码（兼容 macOS 旧格式 `[String]`）
- `SpeechProgressMatcher.swift`：从 macOS `SpeechRecognizer` 抽取的字符级/词级模糊匹配核心

#### Phase 2 — iOS App 壳层 ✅
- 新增 `TextreamiOS` target / scheme（不破坏现有 macOS target）
- `TextreamiOSApp.swift`：App 入口
- `IOSHomeView.swift`：Home / 脚本编辑器
- `IOSReaderView.swift`：全屏提词阅读页
- `IOSSettingsView.swift`：设置面板

#### Phase 3 — MVP 阅读功能 ✅
- **Classic 模式**：timer 驱动固定速度自动滚动，支持暂停/恢复/滑杆/点词跳转
- **Voice-Activated 模式**：`AVAudioEngine` 采集电平，说话时滚动、静音时暂停，mic 开关可控
- **Word Tracking 模式**：`SFSpeechRecognizer` + `SpeechProgressMatcher` 实时语音识别推进高亮位置，支持跳转后继续识别

#### 文档存储 ✅
- `IOSDocumentLibrary.swift`：本地 `TextreamDocuments/` 目录管理
- `IOSDocumentLibraryView.swift`：已保存文档列表
- 新建 / 保存 / 打开 / 删除完整闭环

#### 状态与错误处理 ✅
- 统一错误提示通路：`presentedErrorMessage` + alert
- 模式切换状态恢复：`handleSelectedModeChange` / `restoreSessionForCurrentPage`
- Reader 状态增强：文档名、模式标签、识别进度、波形反馈

### 已实现的关键文件

```
Textream/
├── Textream/Core/
│   ├── TeleprompterCore.swift
│   ├── TextSegmentation.swift
│   ├── ScriptDocumentStore.swift
│   └── SpeechProgressMatcher.swift
├── TextreamiOS/
│   ├── TextreamiOSApp.swift
│   ├── IOSTeleprompterModel.swift
│   ├── IOSHomeView.swift
│   ├── IOSReaderView.swift
│   ├── IOSSettingsView.swift
│   ├── IOSAudioMonitor.swift
│   ├── IOSWordTrackingRecognizer.swift
│   ├── IOSDocumentLibrary.swift
│   ├── IOSDocumentLibraryView.swift
│   └── Info.plist
```

### 已知限制

- **iOS target 尚未在真机/模拟器上运行验证**：当前开发机器缺少对应 iOS platform 组件，无法完成 CLI build / 运行测试
- 缺少 `UIDocumentPicker`：当前为 App 内文档库方案
- 保存格式仍为 legacy `[String]`，未迁移到结构化 `ScriptDocument` 格式
- macOS 版 `SpeechRecognizer` 仍保留原有实现，尚未收敛到共享 `SpeechProgressMatcher`

### 下一步建议

1. **真机验证**：按 `docs/ios-device-test-checklist.md` 逐项测试
2. **修复 P1 问题**：权限、语音识别稳定性、状态恢复
3. ** polish**：错误提示细节、UI 微调、状态残留清理
4. **可选增强**：`UIDocumentPicker`、structured document 格式、macOS 共享 matcher 收敛
