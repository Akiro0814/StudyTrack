# 学迹 StudyTrack · iOS

原生 SwiftUI 成绩记录与分析应用，支持 iOS 26.0+ / iPhone。当前分支 **iOS** 用于 iOS 开发与交付；Android 应用请前往 [Android 默认分支](https://github.com/Akiro0814/StudyTrack/tree/Android)。

## 功能

- 无需注册的本机档案、头像和多用户隔离。
- 小学、初中、高中、大学阶段，结构化学期及同阶段科目继承。
- 单条与批量成绩、考试日期和类型、可选三种排名与反思、草稿、编辑、搜索、删除及撤销。
- 分数与排名趋势、同满分多科比较、整个学习阶段汇总。
- 标准 Excel 导入导出、错误与转换预览、完整备份恢复及恢复前快照。
- iCloud 文件夹授权与备份状态、桌面及锁屏小组件、分析深链和配置诊断。
- 深浅色、主题色、壁纸、Liquid Glass、完整八页引导与转场。

## 构建与安装

工程在 `ios/`，配置源为 `ios/project.yml`。本地开发需要 macOS 和 Xcode；生成工程、运行核心/模拟器测试及签名说明见 [iOS 开发文档](ios/README.md)。

在 GitHub Actions 中选择 **iOS** 分支：

- **iOS CI**：核心测试及三种 iPhone 尺寸的宿主 / UI 回归。
- **iOS Unsigned IPA**：生成真机 ARM64 Release IPA，包含小组件扩展。
- **iOS Environment Probe**：查看工具链与可用模拟器环境。
- **iOS TestFlight**：仅从本分支手动运行，须具备有效发行配置。

当前已交付 iOS 1.2.0 build 32。无签名 IPA 需重签后安装；iCloud 容器、App Group 和小组件实际能力取决于有效的签名授权。真实 iCloud 跨设备传输和重签设备上的 WidgetKit 尚未完成真机验证。

## 验证、目录与历史

- [本轮修复、自测证据和验证边界](docs/2026-10-24-platform-validation.md)
- [分支用途与共享目录约定](docs/branches.md)
- [备份交换格式](shared-spec/backup-v1.schema.json)
- [历史 iOS 实施记录](docs/ios-implementation-progress.md)

两个长期分支都保留已有完整源码与 Git 历史。`shared-spec/` 和独立黄金夹具供两端互通验证，Android 代码也保留，便于共享修复与回归；平台开发和自动构建分别通过对应分支进入。
