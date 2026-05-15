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

### 1. 富文本标记渲染（高优先级）✅ DONE
- [x] 新增 ScriptMarkupParser：解析 `**重点**` 粗体、`[pause]` 停顿标记、`[emphasis]` 重读标记、`[slow]` `[fast]` 节奏标记
- [x] 修改 HighlightingTextEditor 支持 attributedString 渲染
- [x] 在 Word Tracking 模式下，不同标记用不同颜色/动画渲染
- [x] 支持 stage directions `[smile]`, `[gesture]` 等半透明灰色渲染
- **Commit**: `feat: 富文本标记渲染 [pause] [emphasis] [slow] [fast] [normal] **bold**`

### 2. 段落导航大纲（高优先级）✅ DONE
- [x] 新增 ScriptOutlineView：解析段落，按空行分段，提取每段首句作为标题
- [x] 集成到 ContentView 侧边栏，点击跳转到对应段落
- [x] 段落编号，当前高亮段落标识
- **Commit**: `feat: 段落导航大纲 ScriptOutlineView`

### 3. 节奏标记可视化（中优先级）🔄 PARTIAL
- [x] `[pause]` → 渲染为视觉停顿指示（"· · ·"）
- [x] `[slow]` `[fast]` → 区域背景色提示（blue/red tint）
- [ ] 时间轴预览：小地图式进度条显示节奏变化

### 4. 练习模式 MVP（高优先级）✅ DONE
- [x] 新增 PracticeSession 模型：存储录音 URL、原始文本、时间轴数据
- [x] 新增 PracticeService：录音开始/停止，使用 AVAudioRecorder
- [x] 新增 PracticeView：练习结束后回放录音，显示时间轴高亮当前播放位置
- [x] 录音与文本对比：显示语音识别结果与原文本
- **Commit**: `feat: 练习模式 MVP PracticeMode`

### 5. 语速分析基础（中优先级）✅ DONE
- [x] SpeechRecognizer 扩展：实时 WPM 计算
- [x] 新增 WPMChartView：语速折线图（SwiftUI Charts）
- [x] PracticeView 中显示语速趋势图
- **Commit**: `feat: 实时语速提示 WPM indicator` + `feat: 练习报告 WPM 图表 WPMChartView`

## 阶段二：中期（AI 增强）

### 6. AI 润色快捷操作（中优先级）✅ DONE
- [x] 编辑器工具栏："缩短30%"、"更口语化"、"加幽默"、"更正式"、"更有力"、"去填充词"
- [x] 选中文字后调用 AI API 润色
- [x] 一键去填充词
- **Commit**: `feat: AI 润色快捷操作 AIPolish`

### 7. 逐句循环练习（中优先级）📋 NEXT
- [ ] PracticeView 中支持框选句子循环播放
- [ ] 句子级别评分（语速、停顿、发音）
- [ ] 弱点句子自动标记到 "难点列表"

### 8. 智能预加载 & 忘词救援（中优先级）✅ DONE
- [x] NotchOverlay 超时预警：剩余时间/字数实时计算
- [x] 检测到长时间停顿时，短暂闪烁下一句关键词
- [x] 填充词实时计数提示
- **Commit**: `feat: 智能预警 & 忘词救援 SmartAlerts`

## 阶段三：长期（数据闭环）

### 9. 演讲档案 & 能力雷达图（低优先级）✅ DONE
- [x] PracticeHistoryView：浏览历史练习记录
- [x] RadarChartView：五个维度（语速控制、停顿节奏、发音清晰、时间把控、音量）
- [x] 进步追踪：评分趋势
- **Commit**: `feat: 练习历史档案 PracticeHistory` + `feat: 能力雷达图 RadarChart`

### 10. Mock Q&A 模式（低优先级）✅ DONE
- [x] 演讲结束后 AI 生成可能被问到的问题
- [x] Q&A 练习模式：语音回答，AI 评估回答质量
- **Commit**: `feat: Mock Q&A 模拟问答模式`

## 提交规范
每个功能点单独 commit，格式：`feat: [功能描述]` 或 `feat: [模块] [功能描述]`
