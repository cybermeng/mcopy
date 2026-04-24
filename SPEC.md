# Spec: mcopy - macOS 剪贴板历史管理器

## Objective

构建一个 macOS 系统级剪贴板历史管理工具，让用户可以：
- 自动记录剪贴板历史
- 通过快捷键快速调出历史列表
- 选择性粘贴历史内容
- 通过状态栏图标管理应用

**用户故事：**
1. 作为用户，我按 Option+V 弹出剪贴板历史列表
2. 作为用户，我可以单击预览历史内容
3. 作为用户，我可以双击或选中后按 Enter 粘贴内容
4. 作为用户，我可以通过状态栏图标查看应用或退出

**成功标准：**
- [ ] Option+V 全局快捷键响应延迟 < 100ms
- [ ] 剪贴板变更监听成功率 > 99%
- [ ] 历史列表支持滚动浏览 100+ 条记录
- [ ] 粘贴操作成功率 > 99%
- [ ] 应用 CPU 占用 < 1%（空闲时）
- [ ] 内存占用 < 100MB

## Tech Stack

| 组件 | 技术 | 版本 |
|------|------|------|
| 语言 | Swift | 5.9+ |
| UI 框架 | SwiftUI | macOS 14+ |
| 状态栏 | AppKit (NSStatusBar) | - |
| 全局快捷键 | Carbon/HotKey 或 NSEvent | - |
| 剪贴板监听 | NSPasteboard | - |
| 数据存储 | SQLite (GRDB.swift) | - |
| 依赖管理 | Swift Package Manager | - |

## Commands

```bash
# 开发
open mcopy.xcodeproj

# 构建
swift build

# 运行
swift run

# 测试
swift test

# 打包发布
xcodebuild -scheme mcopy -configuration Release
```

## Project Structure

```
mcopy/
├── mcopy/
│   ├── App/
│   │   ├── mcopyApp.swift          # 应用入口
│   │   └── AppDelegate.swift       # 应用生命周期
│   ├── Core/
│   │   ├── ClipboardMonitor.swift  # 剪贴板监听
│   │   ├── HistoryStore.swift      # 历史记录存储
│   │   └── PasteManager.swift      # 粘贴管理
│   ├── UI/
│   │   ├── HistoryPanel.swift      # 历史列表面板
│   │   ├── HistoryItemView.swift   # 单条历史项视图
│   │   └── StatusBarMenu.swift     # 状态栏菜单
│   ├── Models/
│   │   └── ClipboardItem.swift     # 数据模型
│   └── Utils/
│       ├── HotKeyManager.swift     # 快捷键管理
│       └── Permissions.swift       # 权限检查
├── mcopyTests/
│   └── ClipboardTests.swift
└── Package.swift
```

## Code Style

### Swift 风格指南

```swift
// 命名规范
struct ClipboardItem: Identifiable {
    let id: UUID
    let content: String
    let timestamp: Date
    let contentType: ContentType
}

// 使用 MARK 组织代码
// MARK: - Properties
// MARK: - Lifecycle
// MARK: - Private Methods

// 错误处理
enum ClipboardError: Error {
    case accessDenied
    case storageFull
    case invalidContent
}

// 异步操作
func saveItem(_ item: ClipboardItem) async throws {
    // implementation
}
```

### 关键约定
- 使用 `private`/`fileprivate` 限制访问
- 依赖注入优先于单例
- SwiftUI 视图使用 `@StateObject`/`@ObservedObject`
- 数据库操作使用 `async/await`

## Testing Strategy

| 类型 | 框架 | 位置 | 覆盖率目标 |
|------|------|------|-----------|
| 单元测试 | XCTest | mcopyTests/ | 80%+ |
| UI 测试 | XCTest | mcopyUITests/ | 核心流程 |
| 集成测试 | 手动 | - | 发布前验证 |

**测试重点：**
- 剪贴板监听事件捕获
- 数据库存储/检索
- 快捷键注册/响应
- 粘贴操作正确性

## Boundaries

### Always
- [ ] 提交前运行完整测试套件
- [ ] 使用 SwiftLint 保持代码风格
- [ ] 新功能必须包含单元测试
- [ ] 主分支保持可构建状态

### Ask First
- [ ] 添加新的第三方依赖
- [ ] 修改数据库 Schema
- [ ] 更改全局快捷键
- [ ] 修改权限要求

### Never
- [ ] 提交硬编码密钥或敏感信息
- [ ] 在未测试的情况下修改核心逻辑
- [ ] 提交二进制文件到版本控制
- [ ] 忽略内存泄漏或性能问题

## Success Criteria

### 功能完成标准
- [ ] Option+V 触发历史面板
- [ ] 历史列表正确显示时间倒序
- [ ] 单击预览内容详情
- [ ] 双击/Enter 执行粘贴
- [ ] 状态栏图标显示应用菜单
- [ ] 支持文本和图片剪贴板内容

### 性能标准
- [ ] 冷启动时间 < 2s
- [ ] 面板弹出延迟 < 100ms
- [ ] 历史加载延迟 < 50ms（100条）
- [ ] 内存占用 < 100MB
- [ ] CPU 占用 < 1%（空闲）

### 质量标准
- [ ] 单元测试通过率 100%
- [ ] 无内存泄漏（Instruments 验证）
- [ ] 通过 Xcode Static Analyzer
- [ ] 支持 macOS 14+ (Sonoma)

## Open Questions

1. 是否需要支持富文本格式（RTF/HTML）？
2. 历史记录是否需要加密存储？
3. 是否需要云同步功能？
4. 最大历史条目数限制？（默认 100）
5. 是否需要排除敏感应用（如密码管理器）的剪贴板记录？
