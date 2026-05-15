# Textream 母语配置 + 难词音标提示功能

## 目标
当演讲者在某个词上停顿太久时，在提词器上显示该词的音标/母语注解提示。

## 功能清单

### 1. 母语配置（Settings）
- [ ] NotchSettings 添加 `nativeLanguage` 配置（默认跟随系统）
- [ ] NotchSettings 添加 `pauseThreshold` 配置（默认 1.5s）
- [ ] NotchSettings 添加 `phoneticSource` 枚举：appleNative / aiGenerated
- [ ] SettingsView 添加母语选择、停顿阈值滑块、音标来源选择

### 2. 逐词停顿追踪（SpeechRecognizer）
- [ ] 记录每个词的开始/结束时间戳
- [ ] 检测单个词上的长停顿（超过阈值）
- [ ] 暴露 `currentDifficultWord`：当前卡住的词
- [ ] 暴露 `difficultWordStartTime`：卡住开始时间

### 3. 音标生成服务（PhoneticTooltipService）
- [ ] Apple Native 模式：使用 Translation framework 获取翻译+音标
- [ ] AI 模式：调用 OpenAI API 生成音标拼读
- [ ] 缓存机制：已查过的词缓存结果
- [ ] 异步加载，不阻塞主线程

### 4. Tooltip 显示（NotchOverlayController）
- [ ] 当检测到长停顿时，在提词器上方/下方显示 tooltip
- [ ] Tooltip 内容：原词 + 音标 + 母语翻译
- [ ] Tooltip 自动消失（用户继续读或3秒后）
- [ ] Tooltip 样式：卡片式，半透明背景

### 5. AI 音标生成 API
- [ ] AIScriptService 添加 `generatePhonetic(word: String, targetLanguage: String)` 方法
- [ ] 提示词：生成音标 + 母语近似读音 + 简短释义

## 提交规范
每个功能点单独 commit