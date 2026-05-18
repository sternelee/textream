# iOS 首页重设计

**日期**: 2026-05-18  
**目标**: 将当前过密的首页重构为移动端友好的 Tab Bar 架构，核心路径为「选脚本 → 一键开始阅读」。

## 问题诊断

当前 `IOSHomeView.swift`（1019 行）在 iPhone 上将五张内容卡堆叠在一个滚动页面中：

- **heroCard** — 标题/描述 + action chips + 4个stat + chars/时长 + 最近文档
- **pageSection** — 所有页面网格
- **editorCard** — 重复标题 + TextEditor + 工具栏 + tags + 进度条
- **modeCard** — 模式选择 + 设置徽章 + 开始阅读按钮
- **sampleScriptsCard** — 测试脚本列表

主要问题：标题重复、统计数据重复、功能分区不清、编辑区竞争屏幕空间。

## 方案选型

选择 **方案 A**：Tab Bar + 极简首页

## 架构设计

### 导航结构

```
TextreamiOSApp
└── IOSRootTabView (新增: TabView)
    ├── Tab 0: IOSHomeView (首页)     [play.circle.fill]
    ├── Tab 1: IOSDocumentLibraryView (脚本库) [doc.text.fill]
    └── Tab 2: IOSSettingsView (设置)   [slider.horizontal.3]
```

### 新 IOSHomeView（精简）

**内容**（从上到下）：
1. NavigationBar: "Textream" + 右上角"⋯"菜单
2. **脚本卡片**：标题 + 文档名/状态 + 页数/字数 + 预览文本（4行）+ [✏ 编辑脚本] 按钮
3. **阅读模式**：Segmented Picker + 模式说明
4. **[▶ 开始阅读]** 大按钮（56pt 高，主色背景）

**"⋯" 菜单内容**：新建、导入、AI生成、练习、模拟问答、保存、导出

**Sheets**：
- `IOSEditorView`（fullScreenCover）
- `IOSReaderView`（fullScreenCover，现有）
- `AIGenerateView`、`PracticeView`、`MockQAView` 等（sheet）

### 新 IOSEditorView（从 heroCard/editorCard/pageSection 提取）

**内容**（全屏模态）：
1. NavigationBar: "编辑脚本" + 左侧"完成" + 右侧工具图标（省略号菜单）
2. 脚本标题 TextField
3. 页面导航：Prev/Next 按钮 + 当前页信息
4. TextEditor（大区域，minHeight: 280）
5. 进度条 + 字数统计
6. Tags 行
7. 页面网格（底部，可滑动查看）
8. 测试脚本列表

### IOSDocumentLibraryView 改动

- 添加可选回调 `onDocumentLoaded: (() -> Void)?`
- 当作 Tab 使用时：加载文档后调用回调（切换到首页 Tab）
- 移除 NavigationBar 中的"Close"按钮（Tab 模式不需要）

## 文件改动清单

| 操作 | 文件 |
|------|------|
| 新建 | `TextreamiOS/IOSEditorView.swift` |
| 重写 | `TextreamiOS/IOSHomeView.swift` |
| 修改 | `TextreamiOS/TextreamiOSApp.swift` |
| 修改 | `TextreamiOS/IOSDocumentLibraryView.swift` |
