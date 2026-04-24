# Implementation Plan: mcopy

## Overview

构建 macOS 剪贴板历史管理器，核心功能包括：
1. 后台监听剪贴板变化并持久化存储
2. Option+V 全局快捷键弹出历史列表
3. 历史列表支持预览和选择性粘贴
4. 状态栏图标提供应用控制

**实现策略：** 垂直切片开发，每个切片交付可测试的端到端功能

## Architecture Decisions

| 决策 | 选择 | 理由 |
|------|------|------|
| 框架 | SwiftUI + AppKit | SwiftUI 用于面板 UI，AppKit 用于状态栏 |
| 存储 | SQLite (GRDB) | 轻量、可靠、支持查询和索引 |
| 快捷键 | NSEvent 全局监听 | 原生方案，无需额外依赖 |
| 粘贴 | AppleScript + NSPasteboard | 系统级粘贴操作 |
| 面板样式 | NSPanel + SwiftUI | 无边框、可聚焦、动画支持 |

## Task List

### Phase 1: 项目骨架与数据层

#### Task 1: 创建 Xcode 项目结构
**Description:** 初始化 Swift Package Manager 项目，配置基本目录结构和依赖

**Acceptance criteria:**
- [ ] Package.swift 配置完成
- [ ] GRDB.swift 依赖添加
- [ ] 项目目录结构符合 SPEC
- [ ] 项目可编译通过

**Verification:**
- [ ] `swift build` 成功
- [ ] 目录结构与 SPEC 一致

**Dependencies:** None

**Files likely touched:**
- `Package.swift`
- `.gitignore`

---

#### Task 2: 数据模型与数据库
**Description:** 定义 ClipboardItem 模型，实现历史记录存储层

**Acceptance criteria:**
- [ ] ClipboardItem 模型定义（id, content, timestamp, contentType）
- [ ] SQLite 数据库初始化
- [ ] 支持保存、查询、删除操作
- [ ] 自动清理过期记录（>100条）

**Verification:**
- [ ] 单元测试：保存和检索记录
- [ ] 单元测试：自动清理逻辑

**Dependencies:** Task 1

**Files likely touched:**
- `mcopy/Models/ClipboardItem.swift`
- `mcopy/Core/HistoryStore.swift`
- `mcopyTests/HistoryStoreTests.swift`

---

### Checkpoint: Phase 1 完成
- [ ] 项目可编译
- [ ] 数据库存储测试通过
- [ ] 代码提交

---

### Phase 2: 剪贴板监听核心

#### Task 3: 剪贴板监听服务
**Description:** 实现 NSPasteboard 监听，捕获复制事件并存储

**Acceptance criteria:**
- [ ] 监听 NSPasteboard.changeCount 变化
- [ ] 解析剪贴板内容（文本优先）
- [ ] 去重：相同内容不重复保存
- [ ] 后台持续运行

**Verification:**
- [ ] 手动测试：复制文本后数据库有记录
- [ ] 单元测试：去重逻辑

**Dependencies:** Task 2

**Files likely touched:**
- `mcopy/Core/ClipboardMonitor.swift`
- `mcopyTests/ClipboardMonitorTests.swift`

---

#### Task 4: 应用生命周期与后台运行
**Description:** 配置应用为 LSUIElement（无 Dock 图标），初始化监听

**Acceptance criteria:**
- [ ] 应用启动时不显示 Dock 图标
- [ ] 启动时自动开始监听
- [ ] 应用退出时清理资源

**Verification:**
- [ ] 运行应用，Dock 无图标
- [ ] 活动监视器显示进程运行

**Dependencies:** Task 3

**Files likely touched:**
- `mcopy/App/mcopyApp.swift`
- `mcopy/App/AppDelegate.swift`
- `mcopy/Info.plist`

---

### Checkpoint: Phase 2 完成
- [ ] 复制内容自动保存
- [ ] 应用后台运行正常
- [ ] 代码提交

---

### Phase 3: 状态栏菜单

#### Task 5: 状态栏图标与菜单
**Description:** 实现状态栏图标，点击显示"查看"和"退出"菜单

**Acceptance criteria:**
- [ ] 状态栏显示图标（使用系统 SF Symbol）
- [ ] 点击图标显示菜单
- [ ] 菜单项：查看历史、退出应用
- [ ] 菜单项点击响应

**Verification:**
- [ ] 状态栏显示图标
- [ ] 点击查看历史弹出面板（占位）
- [ ] 点击退出关闭应用

**Dependencies:** Task 4

**Files likely touched:**
- `mcopy/UI/StatusBarMenu.swift`
- `mcopy/App/AppDelegate.swift`

---

### Checkpoint: Phase 3 完成
- [ ] 状态栏功能正常
- [ ] 代码提交

---

### Phase 4: 历史列表面板

#### Task 6: 历史列表面板 UI
**Description:** 实现 NSPanel + SwiftUI 历史列表界面

**Acceptance criteria:**
- [ ] 无边框浮动面板（NSPanel）
- [ ] SwiftUI 列表展示历史项
- [ ] 每项显示内容预览（前 50 字符）和时间
- [ ] 支持滚动浏览
- [ ] 面板 ESC 键关闭

**Verification:**
- [ ] 列表正确显示数据库内容
- [ ] 滚动流畅
- [ ] UI 布局符合 macOS 风格

**Dependencies:** Task 2, Task 5

**Files likely touched:**
- `mcopy/UI/HistoryPanel.swift`
- `mcopy/UI/HistoryItemView.swift`

---

#### Task 7: 列表交互（预览与粘贴）
**Description:** 实现单击预览、双击/Enter 粘贴

**Acceptance criteria:**
- [ ] 单击选中项显示完整内容预览
- [ ] 双击选中项执行粘贴
- [ ] Enter 键执行粘贴
- [ ] 粘贴后关闭面板
- [ ] 粘贴操作将内容写入剪贴板并触发粘贴

**Verification:**
- [ ] 手动测试：双击粘贴文本到编辑器
- [ ] 手动测试：Enter 键粘贴

**Dependencies:** Task 6

**Files likely touched:**
- `mcopy/Core/PasteManager.swift`
- `mcopy/UI/HistoryPanel.swift`
- `mcopy/UI/HistoryItemView.swift`

---

### Checkpoint: Phase 4 完成
- [ ] 历史列表完整可用
- [ ] 粘贴功能正常
- [ ] 代码提交

---

### Phase 5: 全局快捷键

#### Task 8: Option+V 全局快捷键
**Description:** 注册 Option+V 全局快捷键，触发显示历史面板

**Acceptance criteria:**
- [ ] 全局监听 Option+V
- [ ] 快捷键触发面板显示
- [ ] 面板已显示时快捷键隐藏
- [ ] 快捷键在应用后台也能响应

**Verification:**
- [ ] 任意应用内按 Option+V 弹出面板
- [ ] 响应延迟 < 100ms

**Dependencies:** Task 6

**Files likely touched:**
- `mcopy/Utils/HotKeyManager.swift`
- `mcopy/App/AppDelegate.swift`

---

### Checkpoint: Phase 5 完成
- [ ] 全局快捷键工作正常
- [ ] 代码提交

---

### Phase 6: 优化与完善

#### Task 9: 支持图片内容
**Description:** 扩展支持图片类型剪贴板内容

**Acceptance criteria:**
- [ ] 检测图片内容类型
- [ ] 存储图片引用或缩略图
- [ ] 列表显示图片预览
- [ ] 图片粘贴功能

**Verification:**
- [ ] 复制图片后历史列表显示图片
- [ ] 双击图片项可粘贴

**Dependencies:** Task 7

**Files likely touched:**
- `mcopy/Models/ClipboardItem.swift`
- `mcopy/Core/ClipboardMonitor.swift`
- `mcopy/UI/HistoryItemView.swift`

---

#### Task 10: 性能优化与内存管理
**Description:** 优化内存占用和响应速度

**Acceptance criteria:**
- [ ] 内存占用 < 100MB
- [ ] 历史列表虚拟化（大量数据时）
- [ ] 大文本内容延迟加载
- [ ] 后台线程执行数据库操作

**Verification:**
- [ ] Instruments 检查无内存泄漏
- [ ] 1000+ 条历史时列表流畅

**Dependencies:** Task 8

**Files likely touched:**
- `mcopy/Core/HistoryStore.swift`
- `mcopy/UI/HistoryPanel.swift`

---

#### Task 11: 配置与偏好设置
**Description:** 添加偏好设置面板（快捷键、历史数量）

**Acceptance criteria:**
- [ ] 设置历史保存数量上限
- [ ] 设置面板可通过状态栏访问
- [ ] 配置持久化保存

**Verification:**
- [ ] 修改配置后生效
- [ ] 配置重启后保持

**Dependencies:** Task 5

**Files likely touched:**
- `mcopy/Utils/Settings.swift`
- `mcopy/UI/PreferencesView.swift`

---

### Checkpoint: Phase 6 完成
- [ ] 所有 SPEC 功能实现
- [ ] 性能指标达标
- [ ] 代码提交

---

### Phase 7: 发布准备

#### Task 12: 应用签名与打包
**Description:** 配置应用签名，打包为 .app 和 .dmg

**Acceptance criteria:**
- [ ] Xcode 项目配置签名
- [ ] 生成可分发 .app
- [ ] 创建 .dmg 安装包
- [ ] README 文档

**Verification:**
- [ ] 未签名运行测试
- [ ] 安装包可正常安装运行

**Dependencies:** All previous

**Files likely touched:**
- `mcopy.xcodeproj/`
- `README.md`

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 全局快捷键与系统冲突 | High | 提供配置选项，检测冲突提示 |
| 辅助功能权限被拒绝 | High | 首次启动引导用户授权，检测权限状态 |
| 内存泄漏 | Medium | Instruments 定期检查，弱引用闭包 |
| 大数据量性能下降 | Medium | 数据库索引、分页加载、虚拟化列表 |
| 剪贴板监听漏事件 | Medium | 轮询+事件双重机制验证 |

## Timeline Estimate

| Phase | 任务数 | 预估时间 |
|-------|--------|---------|
| Phase 1: 项目骨架 | 2 | 2-3 天 |
| Phase 2: 剪贴板监听 | 2 | 2-3 天 |
| Phase 3: 状态栏 | 1 | 1 天 |
| Phase 4: 历史面板 | 2 | 3-4 天 |
| Phase 5: 快捷键 | 1 | 1-2 天 |
| Phase 6: 优化完善 | 3 | 3-4 天 |
| Phase 7: 发布 | 1 | 1-2 天 |
| **总计** | **12** | **13-19 天** |

## Parallelization Opportunities

- Task 5 (状态栏) 可与 Task 3-4 并行开发（需要 Mock 数据）
- Task 11 (偏好设置) 可与 Task 9-10 并行开发

## Open Questions

1. 图片存储策略：原始数据 vs 文件引用 vs 仅缩略图？
2. 是否需要在面板显示搜索功能？
3. 是否需要导入/导出历史功能？
