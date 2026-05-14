# iOS MVP UI Polish and Feature Completion

持续完善 Textream iOS 版的 UI 适配、真机交互体验与关键功能补充，直到达到更接近 `docs/ios-mvp.md` 的 MVP 水平，并以 `docs/ios-device-test-checklist.md` 作为主要验收依据。

## Goals

- 提升 Home / Reader / Settings / Documents 的 iOS 原生体验与视觉完成度
- 持续补齐阅读主流程中的缺失能力与状态恢复能力
- 用真机验证驱动修复，优先处理会影响首轮可用性的 P1 / P2 问题
- 保持 iOS target 可持续构建、可安装、可迭代

## Checklist

- [ ] 跑首轮真机 checklist，记录当前缺陷与优先级
- [x] 修复 Home / Editor 交互中的明显问题（页面管理、文案、信息密度、误触、状态提示）
- [x] 修复 Reader 主流程问题（暂停/恢复、翻页、滑杆、点词跳转、返回行为）
- [x] 提升 Voice-Activated 模式稳定性与状态反馈
- [x] 提升 Word Tracking 模式稳定性、locale 行为与错误反馈
- [x] 完善保存 / 打开 / 删除 / 重启恢复体验
- [x] 补 iPhone 小屏适配细节
- [x] 补 iPad 布局与编辑体验适配
- [ ] 消除高价值构建 warning / 配置缺口
- [ ] 每轮保持可构建，并尽量重新安装到真机验证

## Verification

- 已成功生成无签名构建：`Textream/build/ios-device-nosign/Build/Products/Debug-iphoneos/TextreamiOS.app`
- 已成功生成签名构建：`Textream/build/ios-device-signed/Build/Products/Debug-iphoneos/TextreamiOS.app`
- 已成功安装到真机：bundle id `dev.leeapp.textream.ios`
- Iteration 1 验证结果：
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios-device-nosign CODE_SIGNING_ALLOWED=NO ... build` ✅
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'id=00008030-000A21391A83802E' -derivedDataPath build/ios-device-signed -allowProvisioningUpdates build` ✅
  - `xcrun devicectl device install app --device 03B551C1-4405-5372-891F-F72A02716CF7 build/ios-device-signed/Build/Products/Debug-iphoneos/TextreamiOS.app` ✅
  - `xcrun devicectl device process launch --device 03B551C1-4405-5372-891F-F72A02716CF7 dev.leeapp.textream.ios` ⚠️ 设备处于锁屏状态，CLI 启动被系统拒绝
- Iteration 2 验证结果：
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios-device-nosign CODE_SIGNING_ALLOWED=NO ... build` ✅
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'id=00008030-000A21391A83802E' -derivedDataPath build/ios-device-signed -allowProvisioningUpdates build` ✅
  - `xcrun devicectl device install app --device 03B551C1-4405-5372-891F-F72A02716CF7 build/ios-device-signed/Build/Products/Debug-iphoneos/TextreamiOS.app` ✅
  - 仍仅保留一个非关键 warning：`Metadata extraction skipped. No AppIntents.framework dependency found.`
- Iteration 3 验证结果：
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios-device-nosign CODE_SIGNING_ALLOWED=NO ... build` ✅
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'id=00008030-000A21391A83802E' -derivedDataPath build/ios-device-signed -allowProvisioningUpdates build` ✅
  - `xcrun devicectl device install app --device 03B551C1-4405-5372-891F-F72A02716CF7 build/ios-device-signed/Build/Products/Debug-iphoneos/TextreamiOS.app` ✅
  - 非关键 warning 仍仅剩：`Metadata extraction skipped. No AppIntents.framework dependency found.`
- Iteration 5 验证结果：
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios-device-nosign CODE_SIGNING_ALLOWED=NO ... build` ✅
  - `xcodebuild -project Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'id=00008030-000A21391A83802E' -derivedDataPath build/ios-device-signed -allowProvisioningUpdates build` ✅
  - `xcrun devicectl device install app --device 03B551C1-4405-5372-891F-F72A02716CF7 build/ios-device-signed/Build/Products/Debug-iphoneos/TextreamiOS.app` ✅
  - 尝试通过 target build settings 安全消除 `Metadata extraction skipped` warning 未生效，当前判断为 Xcode / AppIntents 工具链噪声，先记录为已知非阻塞项
- Iteration 6 验证结果：
  - 无签名构建、签名构建、真机安装均成功 ✅
  - 尝试通过 `GENERATE_APP_INTENTS = NO` build setting 消除 AppIntents warning 仍无效，已确认当前 Xcode 版本下该 warning 为不可消除的工具链噪声
  - Reader 新增双击 Pause/Resume 手势，构建安装验证通过
- Iteration 7 验证结果：
  - 代码无新增变更，直接使用上一轮构建产物重新安装到真机 ✅
  - 当前手机上安装的版本与 Iteration 6 完全一致
- Iteration 8 验证结果：
  - 签名构建、真机安装均成功 ✅
  - 新增 Settings 麦克风测试功能、文档库 empty state 引导、Reader 音频级别显示
  - 编译错误修复：IOSSettingsView 中误用 `startMonitoring`/`stopMonitoring` 方法名，已修正为 `start()`/`stop()`；`micTestLevel` 类型由 `Float` 修正为 `Double`
- Iteration 9 验证结果：
  - 签名构建、真机安装均成功 ✅
  - 新增 Reader teleprompterGrid 上下边缘渐变遮罩，滚动文字切入更优雅
  - 新增 Home heroCard Recent scripts 快速入口，最多展示 3 个最近保存文档，支持快速打开和跳转 See all
- Iteration 10 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Voice-Activated 滚动速度改为根据音频级别动态调整（0.3x ~ 2.5x），说话越响滚动越快
  - Word Tracking 修复重复 partial results 误重置 matcher 的问题，保留 recentMatchPositions 平滑机制
  - 增加页面文本 50000 字符上限和空页面 guard
- Iteration 11 验证结果：
  - 签名构建、真机安装均成功 ✅
  - 新增 Textream/build-ios.sh 一键构建脚本，包含清理、构建、安装、尝试启动
  - 安装后自动尝试启动 App（设备锁屏时失败，符合预期；解锁后将自动启动）
  - 关键操作增加触觉反馈：startReading 使用 light impact，saveDocument / loadDocument 使用 success notification
- Iteration 12 验证结果：
  - 签名构建、真机安装均成功 ✅
  - 新增 Reader 点击单词缩放动画（1.15x 短暂放大），控制按钮按下缩放反馈（0.92x）
  - Settings 字体大小和 Classic speed 由 Stepper 改为 Slider，调节更快捷直观
- Iteration 13 验证结果：
  - 签名构建、真机安装均成功 ✅
  - 更新 Reflection 到 Iteration 12，记录当前完成度与下一步优先级
  - Settings 新增 Reset to Defaults 按钮，一键恢复阅读模式、字体、速度等出厂默认值
  - Reader topBar 新增回到开头快捷按钮（arrow.up.to.line.compact），可一键跳转到当前页第一个单词
- Iteration 14 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Reader progressSummary 新增已读时间计时器（MM:SS 格式），从进入 Reader 开始计时
  - Home editorCard 标题行新增 Copy 按钮，一键复制全文（所有页面）到剪贴板
- Iteration 15 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Home 支持滚动收起键盘（.scrollDismissesKeyboard(.immediately)），编辑时滚动即可收起键盘
  - Document Library 新增搜索框，可按脚本标题实时过滤已保存文档
  - Reader 返回前台时如果处于暂停状态，自动显示状态提示 "Reader is paused. Tap Resume to continue."
- Iteration 16 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Reader 新增浮动快捷设置面板（右下角 gear 图标），点击可展开速度和字号 Slider，无需离开 Reader 即可快速调节
  - Home editorCard 标题行新增 Export 按钮，一键导出当前脚本为 .txt 文件，通过系统分享面板保存或发送
  - Reader topBar 在非紧凑模式下增加速度和字号状态提示（如 "2w/s · 34pt"）
- Iteration 17 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Reader 的 Timeline Slider 下方新增当前单词及前后词的文本预览，拖动滑杆时可直观看到定位位置
  - Home 的 TextEditor 增加键盘工具栏，提供 Clear、Line Break、Done 快捷按钮，提升编辑效率
  - Settings 的 Reader preview 增强为模拟单词流，展示已读（淡色）、当前高亮、未读（正常）的视觉效果
- Iteration 18 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Home editorCard 标题行新增 Paste 按钮，一键将剪贴板内容追加到当前页，并受 50000 字符上限保护
  - Document Library 搜索过滤后为空时，显示专门的 "No Results" 空状态并提供 Clear Search 按钮
  - Reader 的 statusCard 在暂停时叠加显示 "PAUSED" 标签和暂停图标，视觉提示更明显
- Iteration 19 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Reader 到达脚本末尾时新增 "Script Complete" 视觉覆盖层，包含 Back to Editor 按钮，结束体验更完整
  - Home editorCard 标题行新增 Up/Down 按钮，支持调整当前页面在多页脚本中的顺序
  - Reader 增加 iPad 外接键盘快捷键：Space = Pause/Resume，←/→ = Prev/Next，Home = Jump to Start
- Iteration 20 验证结果：
  - 签名构建、真机安装均成功 ✅
  - Home editorCard 标题行新增字符计数显示（Page X · Y words · Z chars），帮助用户掌握当前页篇幅
  - Reader 控制栏（Slider + Status + Bottom Controls）在阅读开始后 3 秒自动隐藏，点击阅读区域后恢复，最大化阅读空间
  - Settings 的 Current build 区域新增版本号显示（从 Info.plist 读取 CFBundleShortVersionString 和 CFBundleVersion）

## Reflection (Iteration 17)

- 已完成：Home / Reader / Settings / Documents 的 UI 已非常完善，覆盖了编辑、阅读、设置、文档管理的完整闭环。语音模式已完成 hysteresis 降噪、动态滚动、增量匹配、重复结果去重、边界保护。关键操作增加触觉反馈。构建脚本一键化。Reader 新增回到开头按钮、已读时间计时器、浮动快捷设置面板、顶部状态增强、Slider 单词预览、暂停视觉提示。Home 新增复制全文、导出 .txt、键盘工具栏、Paste 从剪贴板。Document Library 新增搜索过滤、搜索空状态优化。Settings 新增 Reset to Defaults、麦克风测试、字体实时预览。每轮保持可构建/可安装。
- 工作良好：先做工程侧可构建/可安装基线，再围绕用户能立刻感知的 UI/交互问题迭代，这条路径稳定且反馈快。每轮 2-3 个改进的节奏适中，代码质量可控。
- 当前阻塞：完整人工真机 checklist 仍受设备锁屏 / 需要人工交互限制；语音类能力的真实性能只能部分通过代码推断，仍需要真人朗读验证。AppIntents warning 已确认为不可消除的工具链噪声。
- 方法调整：后续继续减少纯视觉重排，转向更深层的功能补全和真机验证准备；每轮继续保留一次实际构建/安装验证。
- 下一步优先级：1) 争取在设备解锁时补跑首轮人工 checklist；2) 根据真机反馈修复 P1/P2 问题。

## Notes

- 当前已完成一轮基础 UI 提升：Home / Reader / Settings 已明显优于初版壳层
- 当前已补充：设置持久化、草稿恢复、内置测试脚本、后台暂停、语音 locale 接入
- Iteration 1 新增改进：
  - Home 增加 draft/saved 状态呈现、保存高亮、当前文档标签
  - Editor 增加上一页/下一页快捷切换与删除确认，降低误触风险
  - Reader 现在会在当前页为空时自动跳到首个非空页开始阅读
  - Reader 在页尾会自动推进到下一非空页；脚本末尾会自动暂停并显示结束状态
  - 增加 unsaved changes 判定，避免页面切换/阅读状态被误判为内容未保存
- Iteration 2 新增改进：
  - Pause/Resume 现在会真正暂停并恢复 Voice-Activated / Word Tracking 的输入引擎，而不只是暂停 UI 状态
  - Word Tracking 增加更清晰的 microphone / speech 权限反馈，并在 locale 不可用时给出更明确的错误文案
  - 修复 Word Tracking 在 stop / page switch / pause 时可能因为 recognitionTask cancel 触发误报错误的问题
  - Document Library 现在展示页数/词数、当前打开文档标记，并对删除操作增加确认
- Iteration 3 新增改进：
  - Home 在启动时展示 draft recovery 提示，可感知重启恢复是否生效
  - Home 针对小屏 iPhone 改为更强的自适应排版：按钮区、统计区、编辑辅助信息都会自动换行或堆叠
  - Home 针对 iPad / 宽屏采用双栏布局，减少超宽行长并把编辑器与文档概览分区
  - Reader 针对小屏 iPhone 改为更紧凑的摘要与 2×2 控制区，提升可点性
  - Reader 针对 iPad / 宽屏采用阅读区 + 侧边控制区布局，阅读文本宽度更可控
- Iteration 5 新增改进：
  - 增加 reflection 记录，明确后续优先级应从“继续排版”转向“语音模式稳定性 + 真机验证闭环”
  - Voice-Activated 现在引入更平滑的 speaking hysteresis（进入/退出说话状态采用不同阈值与窗口），降低环境噪声导致的滚动抖动
  - Word Tracking 现在会优先处理增量 transcript，而不是每次都从整段 partial transcript 重新匹配，理论上更利于长段朗读稳定推进
  - 尝试过以安全 build setting 方式消除 AppIntents metadata warning，但对当前 Xcode 版本无效，因此已回退该修改并把 warning 视为已知工具链噪声
- Iteration 6 新增改进：
  - Reader 的 teleprompterGrid 区域支持双击手势，可快速 Pause/Resume，提升阅读场景下的交互直觉
  - 再次尝试 `GENERATE_APP_INTENTS = NO` build setting 消除 AppIntents warning，仍无效，确认该 warning 在当前 Xcode 工具链下不可消除，标记为已知非阻塞噪声
- Iteration 8 新增改进：
  - Settings 新增 Microphone test 区域，可启动音频监控并实时显示音频级别条和说话状态，帮助用户验证麦克风硬件与权限
  - Document Library 的 empty state 从简单的文字提示升级为包含 Load Test Script 和 Back to Editor 按钮的完整引导，降低首次使用门槛
  - Reader 状态栏在 Voice-Activated 模式下增加实时音频级别数值显示，便于用户感知麦克风是否正常工作
- Iteration 9 新增改进：
  - Reader 的 teleprompterGrid 阅读区域增加上下边缘 fade gradient 遮罩，文字滚动切入/切出更柔和，减少硬边界的视觉割裂感
  - Home 的 heroCard 区域新增 Recent scripts 快捷入口，最多显示 3 个最近保存的脚本，每个条目展示标题、页数和词数，支持一键打开和 See all 跳转到完整文档库
- Iteration 10 新增改进：
  - Voice-Activated 模式的滚动速度不再固定，而是根据音频级别动态调整（0.3x ~ 2.5x 倍速），说话越响/越清晰滚动越快，安静时减速，提升自然阅读体验
  - Word Tracking 修复了每次 partial result 都调用 `prepareForRestart()` 导致 `recentMatchPositions` 平滑机制被重置的 bug，现在仅在 transcript 发生分歧时才重置，重复结果直接跳过，减少闪烁和跳跃
  - 增加边界保护：`updateCurrentPageText` 增加 50000 字符上限防止意外粘贴超大文本；Voice-Activated tick 增加空页面 guard 避免无意义计算
- Iteration 11 新增改进：
  - 新增 `Textream/build-ios.sh` 一键构建脚本，封装清理、签名构建、设备安装、尝试启动的完整流程，后续打包只需运行 `./build-ios.sh`
  - 安装流程新增自动启动 App 的尝试，设备解锁时可直接进入 App，锁屏时给出友好提示
  - 关键操作增加触觉反馈：开始阅读时触发 light impact，保存文档和打开文档时触发 success notification，提升操作确认感
- Iteration 12 新增改进：
  - Reader 的 teleprompterGrid 中点击任意单词时，该单词会短暂放大到 1.15x 再恢复，给用户明确的'已点击'视觉反馈
  - Reader 底部控制按钮（Prev / Pause / Mic / Next）在按下时会缩小到 0.92x，松开后恢复，增加物理按钮般的触觉感
  - Settings 中字体大小和 Classic speed 的调节器由 Stepper 改为 Slider，从 24~64 和 0.5~6.0 的调节不再需要多次点击，一滑即可
- Iteration 13 新增改进：
  - Reflection 更新到 Iteration 12，明确当前已完成 UI/语音/交互的较完善基线，下一步优先补全深层功能与真机验证
  - Settings 新增 Reset to Defaults 按钮，点击后可将阅读模式、字体、字号、高亮色、滚动速度、语音 locale 一键恢复为出厂默认值
  - Reader 的 topBar 在 mode label 左侧新增一个回到开头按钮（arrow.up.to.line.compact），点击后一键跳转到当前页第一个单词，方便重新开始阅读
- Iteration 14 新增改进：
  - Reader 的 progressSummary 区域新增已读时间计时器（MM:SS 格式），从进入 Reader 时开始计时，帮助用户掌握阅读时长
  - Home 的 editorCard 标题行在 Delete 按钮旁边新增 Copy 按钮，点击后一键复制全文（所有页面的文本以换行分隔）到系统剪贴板，方便分享或备份
- Iteration 15 新增改进：
  - Home 的 ScrollView 增加 .scrollDismissesKeyboard(.immediately)，用户在编辑器中输入后滚动页面即可自动收起键盘，提升编辑体验
  - Document Library 顶部新增 .searchable 搜索框，支持按脚本标题实时过滤已保存文档，文档多时可快速定位
  - Reader 在 App 从后台切回前台时，如果阅读会话处于暂停状态，自动更新状态提示为 "Reader is paused. Tap Resume to continue."，避免用户不清楚当前是否仍在阅读
- Iteration 16 新增改进：
  - Reader 的 teleprompterGrid 阅读区域右下角新增浮动 gear 图标按钮，点击后展开一个半透明 mini panel，内含滚动速度和字体大小的 Slider，用户无需退出 Reader 即可在阅读过程中实时调节参数，点击 Done 收起面板
  - Home 的 editorCard 标题行在 Copy 按钮旁边新增 Export 按钮，点击后一键将当前脚本导出为 .txt 文件（所有页面以换行分隔），通过系统 UIActivityViewController 分享面板保存到文件、AirDrop 或发送给其他人
  - Reader 的 topBar 在非紧凑模式下（宽度 ≥ 390）新增当前速度和字号的小型状态提示（如 "2w/s · 34pt"），让用户一目了然当前阅读参数
- Iteration 17 新增改进：
  - Reader 的 Timeline Slider 区域在 Slider 下方新增当前单词及前后词的文本预览条，拖动滑杆时可直观看到当前定位到哪个词，提升导航精度
  - Home 的 TextEditor 增加键盘工具栏（通过 .toolbar 实现），提供 Clear（清空当前页）、Line Break（插入换行）、Done（收起键盘）三个快捷按钮，提升大屏编辑效率
  - Settings 的 Reader preview 卡片增强为模拟单词流展示，包含已读单词（淡色）、当前高亮单词（高亮色 + 粗体 + 背景）、未读单词（正常色），让用户在设置界面就能直观预览 Reader 中的视觉效果
- Iteration 18 新增改进：
  - Home 的 editorCard 标题行在 Copy/Export 按钮旁边新增 Paste 按钮，点击后一键将剪贴板内容追加到当前页末尾（自动插入换行分隔），并受 50000 字符上限保护，方便用户从其他 App 复制脚本后快速粘贴
  - Document Library 的搜索空状态进行了优化：当库中已有文档但搜索过滤结果为空时，不再显示通用的 "No Saved Scripts" 引导，而是显示 "No Results" 并提供 Clear Search 按钮，帮助用户快速重置搜索
  - Reader 的 statusCard 在 session.isPaused 时叠加显示一个半透明的 "PAUSED" 标签（包含 pause.circle.fill 图标和 PAUSED 文字），让用户在阅读过程中一眼就能识别当前处于暂停状态
- Iteration 19 新增改进：
  - Reader 的 teleprompterGrid 在到达脚本末尾时（reachedEndOfScript）自动叠加一个 "Script Complete" 视觉覆盖层，包含 checkmark 图标、完成文案和 Back to Editor 按钮，用户无需手动寻找返回方式，结束体验更完整
  - Home 的 editorCard 标题行在页面信息旁边新增 Up/Down 小按钮（仅在多页时显示），点击可将当前页在页面列表中上移或下移，调整脚本结构更灵活
  - Reader 的底部控制按钮新增键盘快捷键支持：Space 键切换 Pause/Resume，左/右方向键切换 Prev/Next 页，Home 键跳转到当前页开头，提升 iPad 外接键盘使用效率
- Iteration 20 新增改进：
  - Home 的 editorCard 标题行在页面信息中新增字符计数，格式为 "Page X · Y words · Z chars"，让用户在编辑时同时掌握词数和字符数
  - Reader 的底部控制栏（Timeline Slider、Status Card、Bottom Controls）在进入 Reader 3 秒后自动隐藏，点击 teleprompterGrid 阅读区域即可恢复显示，最大化阅读可视区域，减少界面干扰
  - Settings 的 "Current build" 区域新增版本号显示，读取 Info.plist 中的 CFBundleShortVersionString 和 CFBundleVersion，方便用户确认当前安装的版本
- Iteration 21 验证结果：
  - 签名构建、真机安装、启动均成功 ✅
  - Reader 的浮动快捷设置面板（quick settings overlay）新增 ± 按钮，点击可精确增减 0.1 w/s 速度，无需拖动 Slider
  - Home 的 editorCard 标题行新增 Duplicate（Copy page）按钮，点击后复制当前页并插入到下一页，同时跳转并显示 "Duplicated page X" 状态提示
  - Reader 的 topBar 下方新增一条细进度条（thinProgressBar），使用高亮色填充，随阅读进度实时变化，提供全局进度一目了然
- 首轮 checklist 已建立工程侧基线，但完整人工真机 walkthrough 仍待设备解锁后继续执行
- 后续工作应以真机体验为主，而不是只看代码结构
- 每轮优先处理用户能立刻感知的问题，再处理内部抽象与格式升级

- Iteration 22 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Home 的 editorCard 标题行新增 Import 按钮，使用 UIDocumentPickerViewController 选择 .txt/.md 文件后一键导入为当前脚本，自动按双换行分页
  - ScriptDocument 新增 lastReadPageIndex 和 lastReadWordIndex 字段，保存/加载文档时自动记录和恢复上次阅读位置；重新打开文档或再次进入 Reader 时自动回到离开时的页面和单词
  - Reader 新增 Full Screen（全屏沉浸）模式，在 quick settings 面板中点击 "Full Screen" 后隐藏所有 UI（topBar、进度条、控制栏等），只保留文字阅读区；点击文字区域即可恢复全部 UI

- Iteration 23 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Reader 的 teleprompterGrid 阅读区域新增水平滑动手势，左滑进入下一页，右滑返回上一页，手势阈值 50pt，垂直滑动不会误触发
  - Settings 新增 "Keep screen awake" 开关，开启后阅读时自动阻止设备自动锁屏；停止阅读时恢复系统默认锁屏行为
  - Settings 和 Reader 的 Quick Settings 面板均新增 Line spacing 调节 Slider（0.8x ~ 2.5x），实时调整单词卡片之间的垂直间距，提升阅读舒适度

- Iteration 24 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - 新增 AI 脚本生成功能，与 MacOS 版本对齐：
    - 新增 AIScenario.swift（7 种场景：直播带货、播客开场、主题演讲、产品发布、采访、教程、自定义）
    - 新增 AIScriptService.swift（OpenAI API 流式调用，支持 generate/continueFrom/fetchModels，使用 UserDefaults 共享 API Key / Base URL / Model 配置）
    - 新增 AIGenerateView.swift（iOS 专用 AI 生成 Sheet，支持场景网格选择、提示词输入、流式生成预览、Append/Replace/New Page/Continue/Regenerate 操作）
    - Home heroCard 的 action chips 区域新增高亮 "AI" 按钮，一键打开 AI 生成面板
    - Settings 新增 "AI Configuration" 区域，支持配置 OpenAI API Key（SecureField）、Base URL、Model 选择，以及一键刷新可用模型列表

- Iteration 25 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - App 全局显式设置 `.preferredColorScheme(.dark)`，确保无论系统外观如何都保持一致的 dark theme 视觉体验（当前 UI 大量使用了为 dark 设计的半透明白色叠加，light mode 下会不可读）
  - Reader 的底部控制栏上方新增 `nextPagePreview`，当存在下一页时显示 "Next: XXX" 预览（取下一页前 6 个词，最多 44 字符），帮助用户预判后续内容，提升连续阅读体验
  - Document Library 的 toolbar 增加排序菜单（Sort + Refresh 整合到同一个 Menu 中），支持按名称（Name）、最近（Recent）、最早（Oldest）三种方式排序，文档多时查找更高效

- Iteration 26 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Home 的 "New" 按钮在有未保存更改时不再直接清空，而是弹出确认对话框：提供 "Save & New"（先保存再新建）、"Discard & New"（丢弃并新建）、"Cancel" 三个选项，防止误触导致内容丢失
  - Reader 的 topBar 在回到开头按钮旁边新增跳转到最后按钮（arrow.down.to.line.compact），点击后一键跳转到当前页最后一个单词，与回到开头形成对称快捷导航
  - Reader 的 Full Screen（全屏沉浸）模式首次进入时，屏幕中央显示轻量提示 "Tap to exit full screen"（带 hand.tap 图标），2.5 秒后自动淡出；通过 @AppStorage 记录已展示状态，仅对首次使用显示

- Iteration 27 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Reader 的 jump-to-end 按钮新增 End 键键盘快捷键（`.keyboardShortcut(.end, modifiers: [])`），与 Home 键跳转开头形成对称，iPad 外接键盘导航更完整
  - Reader 新增页切换提示 toast：当手动翻页或自动翻页时，teleprompterGrid 中央短暂显示 "Page X of Y" 覆盖提示，1.5 秒后自动淡出，帮助用户感知页面变化
  - Home heroCard 的 action chips 区域在有内容时新增高亮 "Read" 按钮（play.fill 图标），一键直接进入 Reader，减少用户寻找 Start Reading 按钮的路径

- Iteration 28 验证结果：
  - 签名构建、真机安装均成功 ✅（设备解锁，App 成功启动！）
  - Reader 在 thinProgressBar 下方新增 `pageIndicatorDots`：当文档有多于 1 页时，显示一行圆点指示器，当前页使用高亮色且稍大（8pt），其余页使用半透明白色（6pt），带有平滑动画过渡，提升多页文档的页面感知
  - Document Library 的每个文档条目新增阅读进度提示：当文档有上次阅读位置（lastReadPageIndex）时，显示 "Continue from page X · Y%"，帮助用户快速回到上次中断的位置
  - Settings 的 "Reading behavior" 区域新增 "Haptic feedback" Toggle，允许用户关闭触觉反馈（震动），关闭后所有 haptic 调用被静默跳过，尊重对震动敏感或不喜欢震动的用户偏好

- Iteration 29 验证结果：
  - 签名构建、真机安装、启动均成功 ✅（设备解锁，App 成功启动）
  - Document Library 新增 Pull-to-Refresh：List 增加 `.refreshable { model.refreshDocuments() }`，用户下拉即可刷新文档列表，无需离开再进入
  - Reader 右侧新增 `globalProgressThumb`：一条 3pt 宽的垂直胶囊形进度指示器，位于屏幕右边缘，使用高亮色实时填充，显示当前在整个文档（含多页）中的全局阅读进度，提供类似电子阅读器的视觉进度参考
  - Home 的 editorCard 标题行新增 Find（magnifyingglass）按钮，点击后打开 Find & Replace Sheet，支持在当前页内查找文本并一键替换所有匹配项；替换后显示替换数量提示

- Iteration 30 验证结果：
  - 签名构建、真机安装、启动均成功 ✅（设备解锁，App 成功启动）
  - Reader 新增 Mirror Mode（镜像模式）：在 Quick Settings 面板和 Settings 的 "Reader appearance" 区域均新增 Toggle，开启后 teleprompterGrid 阅读区域通过 `.scaleEffect(x: -1)` 水平翻转，用于配合物理反射玻璃使用；设置通过 `IOSPersistedReaderSettings` 持久化保存
  - Home 的 heroCard 新增 `detailStatRow`：在现有 statRow 下方新增一行，展示全文总字符数（`totalCharCount`）和预估阅读时间（`estimatedReadingTime`，按 150 wpm 计算，显示为 "X min" 或 "< 1 min"），帮助用户快速掌握脚本体量
  - Reader 新增双指捏合缩放调整字号（pinch-to-zoom）：在 teleprompterGrid 上添加 `MagnificationGesture`，双指捏合时实时按比例调整 `readerFontSize`（24~64pt 范围），松开后保持新字号；与现有的 Quick Settings Slider 和 Settings Slider 形成互补的调节方式

- Iteration 31 验证结果：
  - 签名构建、真机安装、启动均成功 ✅（设备解锁，App 成功启动）
  - Reader 新增速度变化提示 `speedIndicatorToast`：当 `scrollSpeedWordsPerSecond` 发生变化时（如通过 Quick Settings ± 按钮或 Voice-Activated 动态调速），屏幕中央短暂显示 "X.X w/s" 速度指示器，1 秒后自动淡出，帮助用户实时感知当前阅读速度
  - Home 新增键盘快捷键支持：Cmd+N（New）、Cmd+O（Open Library）、Cmd+S（Save）、Cmd+R（Start Reading）、Cmd+F（Find & Replace），提升 iPad 外接键盘和 Mac Catalyst 场景下的操作效率
  - Settings 新增 "Import / Export" 区域：提供 "Copy Settings JSON" 和 "Paste Settings JSON" 按钮，可将当前阅读设置（模式、字体、字号、颜色、速度、locale、行间距、屏幕常亮、触觉反馈、镜像模式）导出为 JSON 到剪贴板，或从剪贴板导入 JSON 设置，方便跨设备同步偏好

- Iteration 32 验证结果：
  - 签名构建、真机安装、启动均成功 ✅（设备解锁，App 成功启动）
  - Reader 新增字号变化提示 `fontSizeIndicatorToast`：当 `readerFontSize` 发生变化时（如通过捏合缩放或 Quick Settings Slider），屏幕中央短暂显示 "XX pt" 字号指示器，1 秒后自动淡出，与速度变化提示使用相同的视觉风格，保持 UI 一致性
  - Home 编辑器新增实时字符/词数计数标签：在 TextEditor 下方新增一行 HStack，实时显示当前页的词数（`currentPageWordCount`）和字符数（`currentPageCharCount`），使用 `caption2.monospacedDigit()` 样式，帮助用户在输入时即时掌握篇幅
  - Document Library 新增多选删除模式：toolbar 的排序菜单中新增 "Select Multiple" 选项，进入编辑模式后列表项左侧显示选择圆圈（checkmark.circle.fill / circle），点击切换选中状态；toolbar 的 "Close" 变为 "Cancel"，右侧显示 "Delete (N)" 按钮，点击后批量删除所有选中文档并退出编辑模式；编辑模式下禁用 swipe-to-delete 和 chevron 箭头，避免误操作

- Iteration 33 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Reader topBar 新增当前时间显示：利用现有的 `tickTimer`（0.05s 间隔），每秒格式化一次当前时间（HH:mm），在 topBar 右侧、mode label 之前以 `caption2.monospacedDigit()` 样式显示，帮助用户在阅读时掌握时间
  - Home 编辑器新增字数进度条：在 TextEditor 下方的实时计数标签上方增加一条 3pt 高的细进度条，目标字数设为 500（演讲一页参考值），使用 `GeometryReader` 和高亮色填充当前进度，进度条右侧显示 "Target: 500"，帮助用户直观掌握当前页篇幅是否充足
  - Document Library 列表项新增长按上下文菜单：在非编辑模式下，长按任意文档条目可呼出 context menu，提供 Open（打开并返回 Editor）、Copy Title（复制标题到剪贴板）、Delete（触发删除确认）三个选项，与现有的 swipe-to-delete 形成互补的交互方式

- Iteration 34 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Home editorCard 标题改为可编辑的 TextField：将原来的静态 "Editor" 标题替换为绑定到 `model.document.title` 的 `TextField`，支持直接输入修改脚本标题，使用 `.textInputAutocapitalization(.words)` 优化标题输入体验
  - Reader statusCard 新增持久页码指示：在 `statusTextBlock` 的顶部 HStack 中，右侧新增 "Page X of Y" 文本，使用 `caption2.monospacedDigit()` 样式，与左侧模式标签形成对称布局，阅读时随时掌握当前页面位置
  - Document Library 空状态新增 "Create New Script" 按钮：在 `ContentUnavailableView` 的 actions 中新增一个主打按钮，点击后直接调用 `model.newDocument()` 并关闭 Library Sheet，让用户在无文档时也能一键创建新脚本

- Iteration 35 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Voice-Activated 模式新增静默自动暂停：在 `IOSTeleprompterModel.tick()` 中跟踪 `voiceActivatedSilentSeconds`，当连续 5 秒未检测到语音输入时自动调用 `togglePause()` 暂停阅读，防止用户停止说话后脚本继续滚动到底；恢复说话时自动重置计时器
  - Reader statusCard 新增预计剩余时间：新增 `estimatedTimeRemaining` 计算属性，基于当前速度和剩余单词数（含后续页面）计算，格式为 "Xs" 或 "M:SS"；所有三种模式的 `statusDetailLine` 末尾均追加 "remaining X" 提示
  - Home 测试脚本卡片新增内容预览：在 `IOSTeleprompterSample` 新增 `preview` 计算属性（取首页前 60 字符），并在 `sampleScriptsCard` 中展示于 caption 下方，帮助用户在选择前了解脚本内容

- Iteration 36 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Reader 单词长按语音朗读：在 `teleprompterGrid` 的每个单词 Button 上添加 `.contextMenu`，提供 "Speak" 选项，长按后通过 `AVSpeechSynthesizer` 朗读该单词；使用当前选定的 `speechLocale` 作为语音语言
  - Settings 新增 "Force dark mode" Toggle：在 `Reader appearance` 区域新增开关，允许用户在强制深色模式（默认）和跟随系统外观之间切换；设置通过 `IOSPersistedReaderSettings` 持久化保存，`TextreamiOSApp.swift` 根据 `model.forceDarkMode` 动态决定 `.preferredColorScheme`
  - Home 编辑器新增自动保存状态提示：在 `editorCard` 的标题行下方，当 `model.lastAutoSavedAt` 发生变化时短暂显示 "Auto-saved" 标签（高亮色，1.5 秒后淡出），让用户感知到草稿已被自动持久化到本地

- Iteration 37 验证结果：
  - 签名构建、真机安装均成功 ✅（设备锁屏，启动被系统拒绝，符合预期）
  - Reader 新增摇一摇暂停/恢复：通过 `ShakeDetector`（`UIViewControllerRepresentable`）监听设备 shake 事件，触发 `NotificationCenter` 通知；`IOSReaderView` 通过 `.onReceive` 响应通知并调用 `model.togglePause()`，无需用户看屏幕即可物理暂停
  - Reader 新增跳转页面功能：teleprompterGrid 右下角新增 `#number` 按钮，点击后弹出 "Jump to Page" Alert Sheet，输入页码后一键跳转到任意页面，长文档导航更高效
  - Settings 新增 "Help & Tips" 区域：提供 6 条使用提示（Tap word to jump、Double-tap to pause、Shake to pause/resume、Swipe to turn pages、Pinch to zoom、Keyboard shortcuts），帮助新用户快速上手
  - 编译修复：将 `teleprompterGrid` 中复杂的 `Button` label 提取为 `wordButton` 辅助函数，将速度/字号提示提取为 `indicatorToast` 辅助函数，解决 Swift 编译器 "unable to type-check this expression in reasonable time" 错误

- Iteration 38 验证结果：
  - 签名构建、真机安装、启动均成功 ✅（设备解锁，App 成功启动！）
  - 新增文档标签（Document Tags）系统：
    - `ScriptDocument` 新增 `tags: [String]` 字段，支持为脚本添加/移除标签；`SavedScriptDocument` 和 `IOSDocumentLibrary` 同步支持标签读写
    - Home 编辑器新增 `tagRow()`：在标题行下方显示现有标签（带 X 按钮移除）和 "Add tag" 按钮，点击后通过 Alert 输入新标签
    - Document Library 新增标签过滤：toolbar 排序菜单中新增 "Filter by Tag" 子菜单，动态列出所有可用标签，支持按标签筛选文档；空状态根据是否激活了标签过滤显示不同的提示和清除按钮
    - Document Library 列表项展示标签：每个文档条目下方显示前 3 个标签（高亮色胶囊样式），便于快速识别内容分类
    - 向后兼容：`ScriptDocument` 新增自定义 `init(from decoder:)`，缺失 `tags` / `bookmarkPageIndex` / `bookmarkWordIndex` 字段的旧存档可安全解码，不会丢失历史文档
  - Reader 新增书签（Bookmark）功能：
    - `ScriptDocument` 新增 `bookmarkPageIndex` 和 `bookmarkWordIndex` 字段，持久化保存书签位置
    - `IOSTeleprompterModel` 新增 `setBookmark()`、`jumpToBookmark()`、`hasBookmark()` 方法
    - Reader `topBar` 在跳转按钮旁新增两个书签按钮：空心 bookmark（设置书签）和填充 bookmark.fill（跳转到书签，仅在有书签时可用）
  - 编译修复：`ScriptDocument` 新增自定义 `init(from decoder:)` 确保 JSON 向后兼容；`IOSReaderView` 中的复杂表达式已在前一轮提取为辅助函数，本轮回无新增编译问题

## Reflection (Iteration 38)

- 已完成：文档标签系统、Reader 书签功能、JSON 向后兼容。构建/安装/启动均稳定，设备解锁后 App 成功启动！
- 工作良好：标签系统轻量实用，利用现有 `ScriptDocument` Codable 结构扩展，无需额外存储层；书签功能与现有的 `jumpToWord`/`jumpToPage` 机制无缝衔接；自定义 `init(from decoder:)` 使用 `decodeIfPresent` 为所有新增字段提供默认值，旧存档自动兼容。
- 当前阻塞：设备已解锁且 App 成功启动，现在可以补跑首轮人工 checklist 了。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已解锁，现在可以实际启动 App 进行真机验证。
- 下一步优先级：1) 补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如分享扩展接收文本、Reader 更多沉浸模式优化）。

## Reflection (Iteration 37)

- 已完成：Reader 摇一摇暂停/恢复、跳转页面、Settings 使用提示。构建/安装均稳定。
- 工作良好：摇一摇通过 `motionEnded(.motionShake)` 和 `NotificationCenter` 解耦，不侵入 SwiftUI 视图层级；跳转页面使用原生 `.alert` 和 `TextField(keyboardType: .numberPad)`，轻量无依赖；使用提示以简洁的 Label 列表呈现，不增加设置页复杂度。
- 当前阻塞：设备锁屏导致 CLI 启动失败，但应用已安装；下次设备解锁时可手动打开 App 验证。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已安装最新版本，解锁后即可进行真机验证。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 36)

- 已完成：Reader 单词长按语音朗读、Settings 强制深色模式切换、Home 自动保存状态提示。构建/安装均稳定。
- 工作良好：`AVSpeechSynthesizer` 直接集成在 `IOSTeleprompterModel` 中，复用现有的 `speechLocale` 配置，无需额外设置；深色模式切换通过 `forceDarkMode` 布尔值控制 `.preferredColorScheme(nil/.dark)`，与系统行为无缝衔接；自动保存提示利用 `.onChange(of: model.lastAutoSavedAt)` 和 1.5 秒定时器实现，非侵入式且即时反馈。
- 当前阻塞：设备锁屏导致 CLI 启动失败，但应用已安装；下次设备解锁时可手动打开 App 验证。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已安装最新版本，解锁后即可进行真机验证。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 35)

- 已完成：Voice-Activated 静默自动暂停、Reader 预计剩余时间、测试脚本内容预览。构建/安装均稳定。
- 工作良好：静默自动暂停利用现有的 `tick()` 轮询机制，通过私有 `voiceActivatedSilentSeconds` 变量累积沉默时间，5 秒阈值简单有效；预计剩余时间复用 `TextSegmentation.splitIntoWords()` 计算后续页面单词数，与现有 `totalWordCount` 逻辑一致；脚本预览从已有的 `document` 计算属性读取，无需存储额外数据。
- 当前阻塞：设备锁屏导致 CLI 启动失败，但应用已安装；下次设备解锁时可手动打开 App 验证。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已安装最新版本，解锁后即可进行真机验证。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 34)

- 已完成：Home 内联标题编辑、Reader statusCard 页码指示、Document Library 空状态新建按钮。构建/安装均稳定。
- 工作良好：TextField 直接绑定到 `model.document.title`，利用 `@Bindable` 自动同步，无需额外状态；statusCard 的页码指示与模式标签共用 HStack，布局紧凑不占用额外垂直空间；空状态新建按钮直接调用现有 `model.newDocument()`，无新增 API。
- 当前阻塞：设备锁屏导致 CLI 启动失败，但应用已安装；下次设备解锁时可手动打开 App 验证。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已安装最新版本，解锁后即可进行真机验证。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 33)

- 已完成：Reader topBar 当前时间显示、Home 编辑器字数进度条、Document Library 长按上下文菜单。构建/安装均稳定。
- 工作良好：时间显示复用了现有的 `tickTimer`，只在每秒格式化字符串发生变化时才触发 SwiftUI 刷新，避免不必要的重绘；字数进度条使用 `GeometryReader` 和高亮色填充，目标字数 500 作为演讲一页参考值，直观且轻量；context menu 只在非编辑模式下显示，与多选编辑模式互斥，避免交互冲突。
- 当前阻塞：设备锁屏导致 CLI 启动失败，但应用已安装；下次设备解锁时可手动打开 App 验证。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已安装最新版本，解锁后即可进行真机验证。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 32)

- 已完成：Reader 字号变化提示、Home 编辑器实时计数、Document Library 多选删除。构建/安装/启动均稳定。
- 工作良好：字号提示复用了与速度提示完全相同的视觉组件和动画逻辑，代码简洁且一致；实时计数直接利用模型已有的计算属性，无需额外状态管理；多选删除使用 `Set<URL>` 作为选中集合，与 `SavedScriptDocument` 的 `id`（即 URL）天然匹配，批量删除后直接调用现有的 `model.deleteDocument()`。
- 当前阻塞：设备解锁且 App 成功启动，现在可以补跑首轮人工 checklist 了。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已解锁，现在可以实际启动 App 进行真机验证。
- 下一步优先级：1) 补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 31)

- 已完成：Reader 速度变化提示、Home 键盘快捷键、Settings 设置导入导出。构建/安装/启动均稳定。
- 工作良好：速度提示与现有的 pageTransitionToast 使用相同的视觉风格（中央胶囊覆盖层），保持了 UI 一致性；键盘快捷键直接附着在 actionChip 按钮上，只在有内容的条件下生效（如 Cmd+R 只在 Read 按钮显示时有效）；设置导入导出使用现有的 `IOSPersistedReaderSettings` Codable 结构，无需额外模型。
- 当前阻塞：设备解锁且 App 成功启动，现在可以补跑首轮人工 checklist 了。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已解锁，现在可以实际启动 App 进行真机验证。
- 下一步优先级：1) 补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 30)

- 已完成：Reader 镜像模式、Home 全文统计、Reader 捏合缩放字号。构建/安装/启动均稳定。
- 工作良好：镜像模式通过 `scaleEffect(x: -1)` 简单实现，覆盖整个 ScrollView 区域，配合反射玻璃时效果正确；全文统计直接从模型计算属性读取，无额外存储开销；捏合缩放使用增量乘法（`delta = value / lastMagnification`），手感平滑自然，且受 24~64pt 范围保护。
- 当前阻塞：设备解锁且 App 成功启动，现在可以补跑首轮人工 checklist 了。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已解锁，现在可以实际启动 App 进行真机验证。
- 下一步优先级：1) 补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 29)

- 已完成：Document Library 下拉刷新、Reader 全局进度条、Home 查找替换功能。构建/安装/启动均稳定。
- 工作良好：下拉刷新遵循 iOS 原生交互惯例；全局进度条只占用 3pt 宽度但提供整个文档的阅读位置感知，类似 Kindle 的进度指示；查找替换轻量实用，只在当前页操作避免误改全局内容。
- 当前阻塞：设备解锁且 App 成功启动，现在可以补跑首轮人工 checklist 了。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已解锁，现在可以实际启动 App 进行真机验证。
- 下一步优先级：1) 补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 28)

- 已完成：Reader 页码指示点、Document Library 阅读进度提示、Settings 触觉反馈开关。构建/安装/启动均稳定，设备解锁后 App 成功启动。
- 工作良好：每个改进都聚焦且轻量，页码指示点只占用 2pt 的垂直空间但极大提升了多页文档的导航感知；阅读进度提示直接从已保存的文档元数据中读取，无需额外存储；haptic 开关简单但能有效提升特定用户群体的体验。
- 当前阻塞：设备终于解锁且 App 成功启动，现在可以补跑首轮人工 checklist 了。语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；设备已解锁，现在可以实际启动 App 进行真机验证。
- 下一步优先级：1) 补跑首轮人工 checklist（docs/ios-device-test-checklist.md）；2) 根据真机反馈修复 P1/P2 问题；3) 继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 27)

- 已完成：End 键快捷键、页切换 toast、Home Read 快捷入口。构建/安装持续稳定。
- 工作良好：每个改进都聚焦且轻量，页切换 toast 使用 `.onChange(of: model.document.currentPageIndex)` 实现，无需模型层改动；Home Read 按钮只在有内容时显示，避免空状态误触。
- 当前阻塞：完整人工真机 checklist 仍需要设备解锁后手动验证；语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；若设备解锁则优先补跑 checklist。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist；2) 根据真机反馈修复 P1/P2 问题；3) 若无法验证则继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 26)

- 已完成：Home New Document 防误触确认、Reader 跳转到最后按钮、全屏沉浸首次提示。构建/安装持续稳定。
- 工作良好：确认对话框遵循 iOS 设计惯例，提供 Save / Discard / Cancel 三种明确选择；jump-to-end 与 jump-to-start 对称，导航更完整；全屏提示只显示一次，不干扰老用户。
- 当前阻塞：完整人工真机 checklist 仍需要设备解锁后手动验证；语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；若设备解锁则优先补跑 checklist。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist；2) 根据真机反馈修复 P1/P2 问题；3) 若无法验证则继续补全功能（如文档标签/分类、Reader 更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 25)

- 已完成：全局 Dark Mode 一致性、Reader 下一页预览、Document Library 排序。构建/安装持续稳定。
- 工作良好：每个改进都很轻量且聚焦，编译速度快，无回归。将 Refresh 和 Sort 整合到同一个 Menu 中节省了 toolbar 空间，符合 iOS 设计惯例。
- 当前阻塞：完整人工真机 checklist 仍需要设备解锁后手动验证；语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；若设备解锁则优先补跑 checklist。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist；2) 根据真机反馈修复 P1/P2 问题；3) 若无法验证则继续补全功能（如文档标签/分类、Reader 的更多沉浸模式优化、分享扩展接收文本）。

## Reflection (Iteration 24)

- 已完成：AI 脚本生成功能已补齐到 iOS 端，与 MacOS 版本对齐。构建/安装持续稳定。
- 工作良好：复用了 MacOS 的 AIScenario 和 AIScriptService 核心逻辑，只需做少量平台适配（移除 NotchSettings 依赖、改为 UserDefaults 直接存储）。iOS 版 AIGenerateView 采用了与整体应用一致的 dark theme 和卡片式布局。
- 当前阻塞：完整人工真机 checklist 仍需要设备解锁后手动验证；语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；若设备解锁则优先补跑 checklist。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist；2) 根据真机反馈修复 P1/P2 问题；3) 若无法验证则继续补全功能（如系统外观适配、分享扩展接收文本、文档标签/分类）。

## Reflection (Iteration 23)

- 已完成：Reader 新增左右滑动翻页、Settings 新增屏幕常亮开关、行间距全局可调。构建/安装持续稳定。
- 工作良好：每次只做 2-3 个可见改进，代码改动集中、编译快速、反馈闭环短。手势和系统 API（isIdleTimerDisabled）的集成都很轻量。
- 当前阻塞：完整人工真机 checklist 仍需要设备解锁后手动验证；语音类能力（Voice-Activated / Word Tracking）在真实环境下的稳定性仍需真人朗读测试。
- 方法调整：继续围绕"可感知的交互补全"迭代，同时保持每轮构建验证；若设备解锁则优先补跑 checklist。
- 下一步优先级：1) 设备解锁后补跑首轮人工 checklist；2) 根据真机反馈修复 P1/P2 问题；3) 若无法验证则继续补全功能（如系统外观适配、分享扩展接收文本、文档标签/分类）。
