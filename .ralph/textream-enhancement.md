# Textream 提词器 + AI + 口语练习 功能增强计划

## 目标
从提词器、AI、口语练习三个维度系统增强 Textream，每个功能点单独 commit。

## 当前架构速览
- SwiftUI + AppKit macOS 应用
- 核心：SpeechRecognizer（Apple SFSpeechRecognizer 本地识别）、NotchOverlayController（Notch/Floating/Fullscreen 三种显示模式）
- AI：AIScriptService（OpenAI API 流式生成）、AIScenario（7个场景模板）
- 设置持久化：NotchSettings（UserDefaults）
- 页面管理：TextreamService（pages 数组，分页）

## 阶段一：短期（提词器打磨 + 口语 MVP）

### 1. 富文本标记渲染（高优先级）
- [ ] 新增 ScriptMarkupParser：解析 `**重点**` 粗体、`[pause]` 停顿标记、`[emphasis]` 重读标记、`[slow]` `[fast]` 节奏标记
- [ ] 修改 HighlightingTextEditor 或新增 ScriptTextView 支持 attributedString 渲染
- [ ] 在 Word Tracking 模式下，不同标记用不同颜色/动画渲染
- [ ] 支持 stage directions `[smile]`, `[gesture]` 等半透明灰色渲染

### 2. 段落导航大纲（高优先级）
- [ ] 新增 OutlineView / ScriptOutlineView：解析段落，按空行分段，提取每段首句作为标题
- [ ] 集成到 ContentView 侧边栏，点击跳转到对应段落
- [ ] 段落编号，当前高亮段落标识

### 3. 节奏标记可视化（中优先级）
- [ ] `[pause]` → 渲染为视觉停顿指示（如小点/波浪线）
- [ ] `[slow]` `[fast]` → 改变后续文本背景色或字体粗细，提示节奏变化
- [ ] 时间轴预览：小地图式进度条显示节奏变化

### 4. 练习模式 MVP（高优先级）
- [ ] 新增 PracticeSession 模型：存储录音 URL、原始文本、时间轴数据
- [ ] 新增 PracticeService：录音开始/停止，使用 AVAudioRecorder
- [ ] 新增 PracticeView：练习结束后回放录音，显示时间轴高亮当前播放位置
- [ ] 录音与文本对比：显示语音识别结果与原文本的差异（红色标注漏读/错读）

### 5. 语速分析基础（中优先级）
- [ ] SpeechRecognizer 扩展：记录每词识别时间戳
- [ ] 新增 SpeakingStats 模型：WPM、段落级速度曲线、停顿次数/时长
- [ ] PracticeView 中显示语速折线图（SwiftUI Charts）

## 阶段二：中期（AI 增强）

### 6. AI 润色快捷操作（中优先级）
- [ ] 编辑器右键菜单/浮动工具栏："缩短30%"、"更口语化"、"加幽默"、"更正式"
- [ ] 选中文字后调用 AI API 润色
- [ ] 一键去填充词：检测常见填充词并标记

### 7. 逐句循环练习（中优先级）
- [ ] PracticeView 中支持框选句子循环播放
- [ ] 句子级别评分（语速、停顿、发音）
- [ ] 弱点句子自动标记到 "难点列表"

### 8. 智能预加载 & 忘词救援（中优先级）
- [ ] NotchOverlay 超时预警：剩余时间/字数实时计算
- [ ] 检测到长时间停顿时，短暂闪烁下一句关键词
- [ ] 填充词实时计数提示

## 阶段三：长期（数据闭环）

### 9. 演讲档案 & 能力雷达图（低优先级）
- [ ] SessionHistory 模型：持久化每次练习/演出的数据
- [ ] RadarChartView：五个维度（语速控制、停顿节奏、发音清晰、情感表达、时间把控）
- [ ] 进步追踪：同一脚本多次练习的分数趋势图

### 10. Mock Q&A 模式（低优先级）
- [ ] 演讲结束后 AI 生成可能被问到的问题
- [ ] Q&A 练习模式：语音回答，AI 评估回答质量

## 提交规范
每个功能点单独 commit，格式：`feat: [功能描述]` 或 `feat: [模块] [功能描述]`