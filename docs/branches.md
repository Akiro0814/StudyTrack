# 分支与目录

仓库只维护两个长期分支：

| 分支 | 用途 | 构建入口 |
| --- | --- | --- |
| [Android](https://github.com/Akiro0814/StudyTrack/tree/Android) | 默认分支，Android 应用开发与交付 | `app/`、Gradle、Android Verification |
| [iOS](https://github.com/Akiro0814/StudyTrack/tree/iOS) | iOS 应用开发与交付 | `ios/`、XcodeGen、iOS CI / Unsigned IPA |

两个分支均保留已有完整代码与历史，避免清理分支时丢失已完成的跨平台更新。平台目录、共享备份契约和独立测试夹具共同维护；Android 的互通测试仍读取 `ios/StudyTrackTests/Fixtures/`，因此该目录不应在 Android 分支中删除。

- Android 改动从 `Android` 分支开始，PR 目标为 `Android`。
- iOS 改动从 `iOS` 分支开始，PR 目标为 `iOS`。
- 共用格式、黄金夹具或两端都需要的修复，分别同步至两个长期分支，并运行对应检查。
- Android 自动构建仅响应 `Android` 分支；iOS CI 和 IPA 自动构建仅响应 `iOS` 分支。手动运行工作流时选择对应平台分支；TestFlight 仅允许从 `iOS` 运行。
- 临时开发分支在完成同步后删除；版本标签与历史构建记录继续保留。

2026-10-24 清理前，已确认旧 `main` 和全部 `codex/*` 分支的提交均包含在最新交付历史中，并保存了本地完整 Git bundle。已完成改动的历史入口见 [两端验证记录](2026-10-24-platform-validation.md)。
