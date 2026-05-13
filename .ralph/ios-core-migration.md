# Goal
逐步实现 Textream 的 iOS 独立提词器核心功能迁移，优先做可运行的 MVP 壳层与核心交互。

## High-level goals
- 不破坏现有 macOS target
- 新增 iOS 平台壳层与基础页面
- 复用共享核心模型与文档格式
- 先打通 Classic 模式，再逐步接入 Voice-Activated 和 Word Tracking
- 每轮都保持代码可构建、可验证

## Constraints
- 当前工程是 macOS-only，需要谨慎加 iOS target
- MVP 仅关注独立 iOS 提词器，不做悬浮 overlay
- 优先复用已落地的 Core 层：ScriptDocument / ReadingSessionState / TextSegmentation / ScriptDocumentStore

## Iteration checklist
- [x] 添加 iOS target 骨架与入口
- [x] 接入共享核心代码到 iOS target
- [x] 实现 EditorScreen 基础交互
- [x] 实现 ReaderScreen 基础交互
- [x] 实现 Classic 模式自动滚动
- [x] 实现 Voice-Activated 模式
- [x] 迁移 Word Tracking 模式
- [x] 实现本地保存/打开
- [x] 每轮构建验证并记录风险

## Iteration 1 progress

### Completed this iteration
- 新增 `TextreamiOS` target / scheme，并保持现有 `Textream` macOS target 继续可构建。
- 新增 iOS 壳层文件：
  - `Textream/TextreamiOS/TextreamiOSApp.swift`
  - `Textream/TextreamiOS/IOSTeleprompterModel.swift`
  - `Textream/TextreamiOS/IOSHomeView.swift`
  - `Textream/TextreamiOS/IOSReaderView.swift`
  - `Textream/TextreamiOS/IOSSettingsView.swift`
  - `Textream/TextreamiOS/Info.plist`
- iOS 壳层已接入共享 Core：
  - `ScriptDocument`
  - `ReadingSessionState`
  - `TextSegmentation`
  - `ScriptDocumentStore`
- 实现了 Editor 基础交互：页面切换、增删页、脚本编辑、模式选择、开始阅读。
- 实现了 Reader 基础交互：退出、暂停/恢复、上一页/下一页、进度滑杆、点词跳转。
- 打通了 Classic 模式的最小可用闭环：timer 驱动 `wordProgress` 自动推进。

### Validation
- macOS target `Textream` 构建成功。
- Xcode 已识别 `TextreamiOS` target 和 scheme。
- iOS target 无法在当前机器完成 CLI 构建验证，原因是本机缺少对应 iOS platform 组件（Xcode 提示 `iOS 26.5 is not installed`）。

### Risks / notes
- 当前最大风险不是代码结构，而是本地 iOS SDK / platform 环境缺失，导致无法在本机做最终 iOS 编译验证。
- 本轮优先做了安全切片：先完成 iOS 壳层与 Classic 闭环，后续再接入音频和语音识别。

### Next recommended slice
- 接入 iOS `AVAudioSession` + `AVAudioEngine`。
- 实现 Voice-Activated 模式：音频电平检测 + 说话时滚动 / 静音时暂停。
- 如果音频管线稳定，再迁移 Word Tracking 的 speech matching。

## Iteration 2 progress

### Completed this iteration
- 新增 iOS 专用音频监测器 `Textream/TextreamiOS/IOSAudioMonitor.swift`，基于 `AVAudioSession + AVAudioEngine` 采集麦克风电平。
- 在 `IOSTeleprompterModel` 中接入音频监测器，把 `audioLevels / isListening / isSpeaking` 同步到 `ReadingSessionState`。
- 打通 Voice-Activated 模式：只有在检测到说话时才推进 `wordProgress`，静音时停止推进。
- 为阅读页增加状态卡片：显示 mic 状态、模式状态文案、实时 waveform。
- 为阅读页增加 mic 开关按钮，可在 Voice-Activated 模式下开启/关闭监听。
- 为共享 Core 增加 `ReadingSessionState.updateAudio(...)`，让音频状态同步更清晰。

### Validation
- macOS target `Textream` 在本轮修改后继续构建成功。
- iOS target 仍然受本机 Xcode platform 组件缺失影响，无法在当前机器完成最终 iOS CLI 构建验证。

### Risks / notes
- Voice-Activated 的实现已具备 MVP 行为，但尚未在真机/模拟器完成运行校验。
- 当前 `AVAudioSession.recordPermission` / `requestRecordPermission` 逻辑可工作，但在 iOS 真实设备上仍需验证权限弹窗与后台/中断行为。
- Word Tracking 尚未迁移，因此 `wordTracking` 模式目前只有 UI 壳，不具备真实语音对词推进能力。

### Next recommended slice
- 迁移 iOS Speech Recognition 管线。
- 从现有 macOS `SpeechRecognizer` 中抽取可复用的 matching 核心到共享层。
- 把 iOS 的 partial transcription 接到 `recognizedCharCount`，完成 Word Tracking MVP。
- 然后再接 `.textream` 的本地保存/打开。

## Iteration 3 progress

### Completed this iteration
- 新增共享匹配器 `Textream/Textream/Core/SpeechProgressMatcher.swift`，把 macOS `SpeechRecognizer` 里的字符级/词级模糊匹配核心迁移到跨平台 Core。
- 新增 iOS 语音识别包装器 `Textream/TextreamiOS/IOSWordTrackingRecognizer.swift`，基于 `SFSpeechRecognizer + AVAudioEngine` 获取 partial transcription、音频电平与识别进度。
- 在 `IOSTeleprompterModel` 中接入 Word Tracking：
  - `recognizedCharCount`
  - `lastSpokenText`
  - `audioLevels`
  - mic 开关 / 继续读取时保留已识别位置
- 更新阅读进度映射：Word Tracking 模式下由 `recognizedCharCount` 推导当前词和进度百分比，而不再依赖 `wordProgress`。
- 更新 Reader 交互：Word Tracking 模式下滑杆和点词跳转会驱动识别位置跳转，而非 Classic 的 wordProgress。

### Validation
- macOS target `Textream` 在本轮抽取共享匹配器后仍构建成功。
- iOS target 依旧受本机缺少 iOS platform 组件限制，无法完成 CLI 构建验证。

### Risks / notes
- Word Tracking 的代码路径已经迁移并接线完成，但仍缺少真机/模拟器运行验证，尤其是：
  - iOS 上 Speech Recognition 权限弹窗
  - partial transcription 的实时性
  - 音频会话中断 / route change 行为
- 当前 iOS 版和 macOS 版都拥有一份相近的匹配逻辑：
  - iOS 使用共享 `SpeechProgressMatcher`
  - macOS 仍保留原 `SpeechRecognizer` 内部实现
  后续如果需要进一步收敛，可考虑让 macOS 也切到共享匹配器。

### Next recommended slice
- 实现 `.textream` 的 iOS 本地保存/打开。
- 给 iOS 壳层增加文档新建、保存、重新打开流程。
- 然后做一轮整体 polish：模式切换、错误提示、阅读状态恢复。

## Iteration 4 reflection

### 1. What has been accomplished so far?
- 已完成 iOS target 骨架。
- 已完成 Editor / Reader 基础交互。
- 已完成 Classic 模式。
- 已完成 Voice-Activated 模式。
- 已完成 Word Tracking 的共享匹配核心迁移与 iOS 识别管线接线。
- 现阶段 iOS MVP 的“核心提词能力主链路”已经基本成型，只差本地文档存储与一轮 polish。

### 2. What's working well?
- “先抽共享 Core，再加 iOS 壳层”的路线证明是正确的，改动隔离较好，没有破坏 macOS target。
- `SpeechProgressMatcher` 的抽取让 Word Tracking 的迁移明显顺畅，后续也方便让 macOS 收敛到共享实现。
- iOS UI 采用最小壳层方案推进很快，Classic / Voice / WordTracking 都能在统一模型里演进。

### 3. What's not working or blocking progress?
- 最大阻塞仍是本机缺少 iOS platform 组件，导致无法对 iOS target 做 CLI build / 运行验证。
- 音频与语音识别路径已经接上，但缺少真机/模拟器校验，因此权限、中断、route change 仍是未知风险。
- 本地文档存储闭环已在本轮完成，当前剩余阻塞已从“功能缺口”转为“运行验证缺口”。

### 4. Should the approach be adjusted?
- 大方向不需要调整。
- 接下来应从“继续扩功能”切换到“补齐闭环 + 减少风险”：
  1) 先做本地保存/打开；
  2) 然后做状态提示和错误展示；
  3) 最后再考虑是否需要把 macOS 也迁到共享 matcher。
- 在无法本机运行 iOS target 的前提下，继续保持小步提交、macOS 回归构建、尽量减少脆弱改动。

### 5. What are the next priorities?
- 对已完成的本地文档库做一轮 polish。
- 增加权限/错误提示一致性。
- 优化 Reader 状态展示与模式切换恢复。
- 然后评估是否要补 `UIDocumentPicker` 或继续收敛 macOS 到共享 matcher。

## Iteration 4 progress

### Completed this iteration
- 完成 Iteration 4 reflection，并将阶段性判断写入任务文件。
- 新增 iOS 本地文档库 `Textream/TextreamiOS/IOSDocumentLibrary.swift`：
  - 本地 `TextreamDocuments/` 目录管理
  - `.textream` 列表刷新
  - 保存 / 打开 / 删除
  - 与现有 `ScriptDocumentStore` 兼容
- 新增文档列表页 `Textream/TextreamiOS/IOSDocumentLibraryView.swift`。
- 在 `IOSTeleprompterModel` 中接入文档存储：
  - `newDocument()`
  - `saveDocument()`
  - `loadDocument(...)`
  - `deleteDocument(...)`
  - `refreshDocuments()`
  - 当前文档 URL / 状态消息
- 更新 `IOSHomeView`：
  - New / Open / Save 操作入口
  - Saved Scripts sheet
  - 保存状态提示文案

### Validation
- macOS target `Textream` 在本轮修改后仍构建成功。
- iOS target 依旧无法在当前机器完成 CLI 构建验证，原因仍是本机缺少对应 iOS platform 组件。

### Risks / notes
- 本地文档闭环已补齐，但目前走的是“App 内文档库 + 本地目录”方案，还没接 `UIDocumentPicker`。
- 保存目前使用 `ScriptDocumentStore.saveLegacyPages(...)`，优先保证与现有 macOS `.textream` 兼容；这意味着文档元数据仍主要靠文件名承载。
- 如果后续要支持更完整的状态恢复（如页码、已读页、模式偏好），可以考虑逐步切到 structured document 格式。

### Next recommended slice
- 做一轮整体 polish：
  - 权限/错误提示统一
  - Reader 状态展示优化
  - 模式切换时的状态恢复一致性
- 然后评估是否需要补 `UIDocumentPicker` 或继续收敛 macOS 到共享 matcher。

## Iteration 5 progress

### Completed this iteration
- 统一了 iOS 壳层的错误提示通路：
  - `IOSTeleprompterModel.presentedErrorMessage`
  - `runtimeErrorMessage`
  - `consumeSubsystemErrors()`
  - `dismissPresentedError()`
- 优化了模式切换和会话恢复一致性：
  - `selectedMode` 切换时统一走 `handleSelectedModeChange(...)`
  - `restoreSessionForCurrentPage(...)` 统一翻页/跳页/重新开始时的状态恢复
- 增强了 Reader 状态展示：
  - 顶部显示当前文档名
  - 状态卡片显示更明确的模式/识别进度信息
  - waveform 在 Word Tracking 下使用独立视觉反馈
- Home / Reader 两侧都接入了统一 alert 弹窗，避免错误只埋在状态文案里。
- 完成文档体验评估：
  - 当前阶段**不优先补 `UIDocumentPicker`**，先保留 App 内文档库方案；
  - 当前阶段**不优先切 structured document 保存格式**，优先保持 `.textream` 与 macOS 兼容。

### Validation
- macOS target `Textream` 在本轮 polish 后继续构建成功。
- iOS target 仍受本机 iOS platform 组件缺失限制，无法完成 CLI 构建验证。

### Risks / notes
- iOS MVP 代码上已基本形成完整闭环，但缺少最关键的真机/模拟器运行验证。
- 由于当前不引入 `UIDocumentPicker`，iOS MVP 的文档体验更偏“App 内草稿库”，适合第一版，但不等于系统级文件互通。
- 由于当前继续写 legacy `[String]` 格式，文档恢复仍不包含更丰富的会话元数据；这对 MVP 可接受，但会限制后续高级恢复能力。

### Next recommended slice
- 做一轮最终 MVP 收尾：
  - 清理状态文案与错误提示细节
  - 统一保存后/打开后/切模式后的提示行为
  - 检查是否存在明显的状态残留 bug
- 然后输出一份当前 iOS MVP 的完成度总结与后续建议。

## Working style
- 每轮选择最小可交付切片
- 先实现，再验证，再汇报
- 若遇到工程结构风险，优先做最小安全改动
- 修改后尽量执行构建验证
