# iOS 实施记录

实施日期：2026-10-14。规格来源：`docs/iOS开发实施文档.md`。

## 采用的设计

采用文档默认范围：iOS 26+、iPhone、Swift 6 / SwiftUI、GRDB、Swift Charts，五个系统 Tab。首版无云同步和支付。分数为百分之一分整数，日期为公历日，所有业务操作显式捕获用户与学期。数据库约束、批量事务和备份恢复优先于页面装饰。原生玻璃只用于控制层，内容保留可读背景；按 ui-design-system 技能使用系统文字样式、44pt 操作区与深浅色适配。

Excel 引擎候选的实施取舍：使用 ZIPFoundation + Foundation XMLParser 实现有限的 OOXML 适配器，同时用于 ZIP 备份。减少 C 桥接与 XMLCoder 传递依赖，保持真正 `.xlsx`；支持范围以夹具和明确拒绝规则界定，不提供公式求值、宏或旧 `.xls`。这替换文档中的候选库，不改变交换契约。

## 实施计划

1. 创建 App/Unit/UI targets、固定版本依赖、构建及发布脚本；Swift Package 提供独立业务测试入口。
2. 先加入规则、数据库与文件交换测试，再实现 Domain、SQL migration、作用域仓库及统计。
3. 实现引导、用户/学期、科目、单条/批量成绩、筛选分页和图表。
4. 实现安全文件暂存、XLSX 预览/事务提交/报告、ZIP 全量快照/验证/替换恢复、壁纸与草稿。
5. 新增 Android 全量备份适配器及入口，持久化数据集身份与旧 ID 映射。
6. 执行当前环境可用的检查，记录真实结果与 macOS/真机待验收项。

## 验证边界

当前目录没有 `.git`，不初始化或推送未经确认的远程。Windows 没有 Xcode、Swift 或已授权 Apple 签名材料。依赖锁与工具链实测信息由 macOS 脚本输出 artifact，不伪造已通过的组合。CI、TestFlight、真机、最低系统和性能验收须有真实运行证据后才能关闭。

## 用户确认的交付方式

用户指定真实仓库 `https://github.com/L1angK1NG/StudyTrack`，无 Apple Developer 账号，使用自己的签名证书安装。交付改为 macOS CI 编译 iphoneos/arm64 Release，再生成 `Payload/StudyTrack.app` 的未签名 IPA，供用户自行重签。TestFlight 工作流保留为可选发布路线，不作为本次交付前置条件。

真实仓库已克隆到独立目录 `E:\Project\StudyTrack-iOS-delivery`，不重建原目录历史；改动将在独立开发分支上构建验证。

## 已实现的代码范围

| 范围 | 文件入口与行为 |
|---|---|
| M0 工程与构建 | `ios/project.yml`、3 个 Xcode targets、独立 StudyTrackCore package、精确 SPM 版本与 Package.resolved、固定 XcodeGen 2.44.1 / 实测下载散列 |
| M1 数据基础 | `Domain/Models.swift`、`Data/Database/schema.sql`、`StudyStore.swift`：定点分数、公历日期、复合作用域外键、唯一键、迁移、选择修复 |
| M2 成绩管理 | 科目 CRUD、单条/批量成绩、逐行校验、事务提交、丢弃确认、用户/学期管理、按 scope 保存草稿 |
| M3 首页与分析 | 五个独立系统导航栈、全量筛选摘要、50 条分页、按科目分数图/反向排名图、保峰谷抽稀、文字明细 |
| M3 个性化 | 简洁/玻璃主题、系统深浅色、强调色、PhotosPicker 壁纸降采样与不可变落盘、减少透明度按钮回退 |
| M4 文件交换 | `XLSXCodec.swift`、`ImportService.swift`：真正 OOXML、稀疏列与共享字符串、1900/1904 日期、预览、转换确认、冲突/重复报告、revision 检查、原子导入 |
| M5 完整备份 | ZIP 清单/计数/散列/路径/限额检查、全量引用与约束校验、替换前快照、不可变资源先安装、数据/设置/操作日志同事务、启动修复 |
| M5 Android 适配 | `BackupExporterV1.kt`、Settings 入口：全库一致性读取、持久化 dataset/ID 映射、资源字节、原时区确认、无损转换失败阻止 |
| M6 交付资源 | 既有 logo 制作 AppIcon、String Catalog、隐私清单、关于/支持与第三方许可、构建文档、自签 IPA 工作流；TestFlight 为可选 |

## 当前已取得的验证证据

1. Windows Node 24 直接执行实际 schema.sql：作用域外键、唯一键、分数/排名检查、事务回滚、级联删除通过。
2. Swift 6.1.3 / Linux 容器：19 项 XCTest 全部通过。覆盖两位分数、评级边界、严格日期/Excel 日期、规范化、数据隔离、重名错误、原子批量、分页摘要、字面搜索、跨学期/重复/过期导入、恢复与未知 Android 扩展、用户删除选择修复、独立夹具、图表保峰谷抽稀、磁盘重新打开与 10000 行数据。
3. 10000 行的预览、导入、重新打开、完整备份与校验约 18 秒，为本次宿主机合成数据测量，不代表 iPhone 性能或内存验收。
4. 独立 openpyxl 读写和 Apache POI **5.2.3** 互操作通过；POI 生成共享字符串工作簿由 Swift 读取，iOS 导出由 POI 读取。验证的是交换引擎，不冒充 Android 应用界面往返验收。
5. Python 独立检查 workflow YAML、配置 JSON、Privacy plist、backup-v1 schema 和黄金/导出备份通过。Bash 语法检查、SwiftUI 源码语法解析通过。
6. 实际 Android `BackupValues.kt` 使用 Kotlin/JVM 编译运行，精度、原时区和 NFC 规则检查通过。完整 Android 构建尚未通过：本机原始 wrapper 缺少 PathTraversalChecker，既有 org.gradle.java.home 与 SDK 路径也不存在；没有将这些已有环境问题记成成功。
7. GitHub macOS 26 / Xcode **26.6 (17F113)** 真机 Release 构建成功，首次 IPA 来自 commit `53856b33d969e9c59952c63de8d53592489d6abe`、[run 38529479483](https://github.com/L1angK1NG/StudyTrack/actions/runs/38529479483)。已下载检查 `Payload/StudyTrack.app`、`iphoneos`、arm64、最低 26.0、SHA-256。首次包发现 XcodeGen target 默认设备族覆盖全局 iPhone 设置，已在最终配置中显式修正为 iPhone。

本机证据位于未提交的 `artifacts/`，包含测试日志、独立互操作日志和实际 IPA。源码与夹具在开发分支提交，构建产物由 Actions artifacts 提供。

## 尚需真实设备或额外环境的验收

- 模拟器 App/Unit/UI 测试矩阵结果与最终 commit 的 IPA 持续跟进，以实际运行结果更新本节。
- iOS 26.0 最低系统、用户自行重签后的安装、原生玻璃观感、文件/iCloud 选择、返回手势、最大动态字体、VoiceOver、后台终止恢复及真机性能尚未验收。
- Android 完整应用构建与实际 Android→iOS 全量资源迁移还需 Android SDK / CI 和设备验证；不能用 JVM 规则与 POI 引擎测试替代。
- 首版保守保留旧资源与恢复快照，无自动垃圾回收；大备份采用受限内存解析，峰值内存必须在真机测量，不能提前宣称达到 250MB 目标。
- 未加入 iPad 独立适配、云服务、支付、旧 XLS、公式计算或合并恢复，与原文默认首版范围一致。
