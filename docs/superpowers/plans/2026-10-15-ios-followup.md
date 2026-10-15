# iOS 实机反馈修复实施计划

**Goal:** 交付本轮 8 项修复及可重签 IPA。

**Architecture:** 保留 SwiftUI + StudyStore actor；使用系统滚动边缘和文档选择器处理原生行为，授权目录备份独立于专属 iCloud 容器。异步合并小组件刷新，CRUD 不等待导出。

**Tech Stack:** Swift 6、SwiftUI/UIKit、GRDB、NSFileCoordinator、WidgetKit、Xcode 26。

- [x] 检查手势、文件选择、容器、学期和刷新实现；新增首次引导和左滑回归 UI 测试并推送基线验证。
- [x] `Atmosphere.swift` 与首页/分析：左滑删除，exclusive drag/tap，补充无障碍编辑/删除；原生 soft 滚动边缘替换顶部 overlay。
- [x] `OnboardingView.swift`：三页引导、跳过/下一步/开始；设置支持重新查看；更新首次创建测试。
- [x] `DocumentPicker.swift`：通用文件打开副本、目录原址授权；`DataTransferView` 复用，选后校验仍由现有 codec 完成。
- [x] `CloudBackupService/View`：目录书签、协调读写、容器回退、独立备份恢复；测试本地授权目录上传/列表/下载/校验，错误不吞掉。
- [x] `SemesterProgression` + `SemesterViews`：阶段与学期分离、补齐/推进、边界确认，旧学期归类；测试 4 阶段、空阶段、缺项、完整阶段、大学结束、继承与跨阶段隔离。
- [x] `AppModel/WidgetBridge/StudyStore`：资源表读取、删除计数、延迟小组件刷新、后台写盘、延迟忙碌反馈；测试最后一次更新和空资源。
- [x] 本地数据库契约验证；macOS 核心测试 + 三款 iPhone 模拟器 + Release；读取失败日志再修复，不把静态检查当作编译证据。
- [x] 检查截图、下载并核验新 IPA 版本/扩展/摘要；保留旧 build24，更新本轮验收报告。

测试命令：Windows `node ios/Scripts/check-contracts.mjs` 与 `node ios/Scripts/check-school-contracts.mjs`；macOS `cd ios && swift test --parallel`、`bash ios/Scripts/test-simulator.sh`、`bash ios/Scripts/build-unsigned-ipa.sh`。macOS 由现有 GitHub Actions 执行。
