# iOS 体验实施计划

**Goal:** 交付修复壁纸/图表并重写 UI 的可重签 IPA。

**Architecture:** 保留 StudyStore 与文件交换契约；新增纯业务趋势点与档案头像引用，SwiftUI 统一背景/内容容器/录入协调器。

**Tech Stack:** Swift 6、SwiftUI、Swift Charts、PhotosPicker、ImageIO、GRDB、GitHub macOS CI。

## 1. 回归与数据

- [x] `ExperienceTests.swift` 先定义同日不同序号、缺失排名和头像备份/引用检查；UI 测试定义首次添加科目→成绩流程。
- [ ] CI 验证新增测试在旧实现失败。
- [ ] `Domain/ExamTimeline.swift` 用稳定 date/createdAt/id 排序，枚举独立 position，再对点抽稀；排名在枚举后过滤。
- [ ] `Preferences` 扩展读写 ios.profileAvatars；StudyStore 验证与删除清理；验证旧备份和新头像备份均可恢复。

## 2. 背景、身份与组件

- [ ] `AppModel` 同步当前头像和壁纸缓存，图片保存后/恢复/切换用户刷新。
- [ ] `FileService` 共享图片落盘流程，头像 512px。
- [ ] `ExperienceComponents.swift` 提供 AppCanvas、StudyScroll、StudySurface、AvatarView、品牌、可操作空状态、科目筛选和录入协调器。
- [ ] Root 的每个导航容器使用共享背景；List/Form 显式隐藏系统背景。Reduce Transparency 回退为高对比实色内容。

## 3. 页面

- [ ] Home/Subjects/Exams/Analysis/Settings/Personalization/Onboarding 重写；最近记录能编辑，空状态有动作，头像入口可达。
- [ ] Subject/Exam/Batch 编辑增加标签、键盘行为、可选字段层级；保留草稿和丢弃确认。
- [ ] 导入导出/用户/学期/关于使用同一背景和分区语言；版本从 Bundle 读取。

## 4. 交付

- [ ] `node ios/Scripts/check-contracts.mjs`、Swift 核心回归、三机型 UI、带图片 UI 截图检查。
- [ ] Release iphoneos IPA；读取 Info.plist、arm64、CRC、散列，写入交付记录。
- [ ] 将源码同步原工作目录，推送已有开发分支，提供新 IPA 和明确验证范围。
