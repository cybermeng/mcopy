# mcopy

macOS 剪贴板历史管理器，自动记录复制历史，快捷键快速粘贴。

## 功能

- 自动监听并记录剪贴板历史（文本 + 图片）
- `Option+V` 全局快捷键弹出历史列表
- 单击选中、双击或 Enter 粘贴
- Delete 键或右键菜单删除单条记录
- 搜索过滤历史条目
- 敏感应用自动排除（1Password、Bitwarden 等）
- 图片缩略图预览 + 图片粘贴
- 偏好设置：历史数量、轮询间隔、开机自启动
- 状态栏菜单：Show History / Clear History / Preferences / Quit
- SQLite 持久化存储（GRDB.swift），自动去重 + 超量清理
- 无 Dock 图标，纯状态栏应用

## 系统要求

- macOS 14.0+ (Sonoma)
- Apple Silicon 或 Intel Mac

## 安装

### 下载

下载 [mcopy.dmg](mcopy.dmg)，拖入 Applications 文件夹。

### 从源码构建

```bash
git clone <repository-url>
cd mcopy

# 构建
swift build -c release

# 打包为 .app + .dmg
bash release.sh
```

输出：`.build/release/mcopy.app` 和 `mcopy.dmg`

## 使用

| 操作 | 说明 |
|------|------|
| `Option+V` | 显示/隐藏历史面板 |
| 单击列表项 | 选中 |
| 双击列表项 | 粘贴到当前应用 |
| `Enter` | 粘贴选中项 |
| `Delete` | 删除选中项 |
| 右键菜单 | Paste / Delete |
| `Esc` 或点击外部 | 关闭面板 |
| 底部 Paste 按钮 | 粘贴选中项 |

## 权限

首次运行需授予辅助功能权限（用于全局快捷键和模拟粘贴）：

1. 打开 **系统设置 → 隐私与安全性 → 辅助功能**
2. 添加并启用 mcopy

## 项目结构

```
mcopy/
├── mcopy/
│   ├── mcopyApp.swift          # 应用入口 + AppDelegate
│   ├── Core/
│   │   ├── ClipboardMonitor.swift  # 剪贴板轮询 + 敏感应用排除 + 图片保存
│   │   └── HistoryStore.swift      # SQLite/GRDB 存储 (actor 隔离)
│   ├── Models/
│   │   └── ClipboardItem.swift     # 数据模型 + ImageCache 单例
│   ├── UI/
│   │   ├── HistoryPanel.swift      # 历史面板 (NSPanel + SwiftUI)
│   │   ├── StatusBarController.swift # 状态栏图标 + 菜单
│   │   └── PreferencesView.swift   # 偏好设置 + 开机自启动
│   ├── Utils/
│   │   └── HotKeyManager.swift     # Carbon 全局快捷键
│   ├── Info.plist
│   └── mcopy.entitlements
├── Package.swift
├── release.sh
└── mcopy.dmg
```

## 技术栈

- Swift 5.9+ / SwiftUI + AppKit
- GRDB.swift (SQLite)
- Carbon Event Manager (全局热键)
- CGEvent (模拟 Cmd+V 粘贴)

## 许可证

MIT
