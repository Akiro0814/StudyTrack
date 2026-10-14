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
