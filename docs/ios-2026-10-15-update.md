# 2026-10-15 iOS 更新与验收记录

本次按用户确认的 17 项方案实施。大学阶段固定为大一至大四、每年上下学期。当前工作目录为 `E:\Project\StudyTrack`；Git 交付目录为 `E:\Project\StudyTrack-iOS-delivery`，开发分支 `codex/ios-experience-20261015`。主分支未修改。

## 功能对应

| 需求 | 实现与主要入口 |
| --- | --- |
| 1 首次头像设置 | `ProfileSetupForm`：照片选择、预览、可稍后设置，创建用户时同事务保存资源引用 |
| 2 引导表单割裂 | 主操作放入档案表单；取消独立键盘工具栏和底部 bar，姓名使用键盘完成键收起 |
| 3 两级学期 | `SchoolTerm`、`SchoolTermPicker`：四阶段 32 个标准学期；旧学期兼容识别/归类 |
| 4 个性化 | 默认模糊卡片 / 原生液态玻璃；二级材质参数；亮/暗/跟随系统；删除预览卡；主题色预设和 HSB、RGB、HEX 自定义 |
| 5 作者信息 | 设置页底部作者、GitHub 和邮件链接 |
| 6 最近足迹右滑删除 | `SwipeDeleteRow`、`AppModel.deleteRecord`，提供 8 秒撤销和无障碍动作 |
| 7 首页分科统计 | `StudyStore.analysis` 读取完整记录；逐科平均分、最高分、优秀率；无成绩显示暂无记录 |
| 8 成绩分析合并 | 四 tab；同满分多科图；默认折叠明细、50 条继续加载；保留搜索、单条/批量录入、编辑和删除 |
| 9 图表动效 | 分组图和单科图从左到右揭示曲线；减少动态效果时直接显示 |
| 10 顶部渐进模糊 | `ProgressiveTopBlur` 接入滚动页及通用表单/列表背景；不拦截触摸 |
| 11 桌面/锁屏组件 | `StudyTrackWidgets`：桌面小中大、锁屏矩形/圆形/行内；范围选择、隐私标记、趋势和统计、跳回分析 |
| 12 XLSX 文件选择 | 明确 UTI 声明，兼容通用文件提供方；选中后校验扩展名与真实内容，仍经过导入预览 |
| 13 壁纸文字 | 亮度采样选择壁纸上的文字方案；内容卡片独立遵循亮暗模式；主题主按钮自动选择黑白文字 |
| 14 多用户限制 | 创建入口、多用户创建和切换的数据层保护；不通过设置写入偷偷切换作用域 |
| 15 科目继承 | `saveSchoolSemester` 同阶段最近学期继承，独立科目 ID，不复制成绩；事务失败整体回滚 |
| 16 阶段汇总 | 同用户、同阶段跨学期逻辑科目归并；原始满分不同则分组；归类旧学期时连接无歧义的同名科目 |
| 17 iCloud | 专属 Drive 容器；带时间戳完整备份；元数据发现和上传状态；下载、校验、恢复预览、本机恢复快照 |

## 数据兼容

- 保留 v1 原表和主键，新增 `v2-school-system` 迁移；元数据表有复合外键、阶段/年级/上下学期范围限制与唯一约束。
- 备份新增可选 `schoolTerm` 和 `lineageID` 字段，旧备份缺少这些字段仍可解码。`shared-spec/backup-v1.schema.json` 已同步。
- 无法确认的旧学期不自动猜测；重复标准学期不自动合并。阶段汇总不会夹带未归类或其他用户的数据。
- 导入未知学期先做两级映射，文件本身不被修改。旧 XLS、加密或损坏工作簿不宣称支持。
- 多科图按日期及稳定顺序排列，同日成绩各有位置；绘图每科最多约 200 点，保留峰谷，统计和明细不使用抽稀数据。

## 验证记录

- 本机 `node ios/Scripts/check-contracts.mjs`：通过。
- 本机 `node ios/Scripts/check-school-contracts.mjs`：通过。包含元数据用户隔离、标准学期唯一、阶段/年级/上下学期约束和级联删除。
- PowerShell `Test-Json` 独立 JSON Schema 校验：旧黄金备份数据与自定义 HEX 主题色设置通过；备份契约的主题色字段已扩展为预设或六位 HEX。
- macOS 核心测试：31 项通过，包括旧库升级、归类继承链和 600 条同日曲线抽稀回归。截图检查另外发现同日数据被默认横轴范围压缩，已补显式域和同日次序刻度，并加入域宽断言。
- 本机 Docker 因已有 secrets-engine socket 错误无法启动；未重置 Docker 或修改用户容器数据。Swift/Xcode 验证使用已有 GitHub macOS 通道。
- Release 构建：[run 38710971908](https://github.com/L1angK1NG/StudyTrack/actions/runs/38710971908) 成功，源码 commit 3dac922978d9572aa794b4566d68c70c8d836737；日志没有 warning/error。
- 成品：`E:\Project\StudyTrack\StudyTrack-2026-10-15-build24-unsigned.ipa`；版本 1.1.0，build 24，iOS 26.0+，arm64，7,288,993 字节。
- 成品 SHA-256：`fed3ff89ad54e519317b03921b430ed3103034f3dca3e5428422b5baecc0c2be`。已核对远端散列、主应用与扩展的 Mach-O 架构、版本一致性、扩展嵌入、App Intents 元数据、XLSX UTI、iCloud 容器声明和深链接配置。
- 通用交付路径 `StudyTrack-unsigned.ipa` 已更新；旧 build 14 独立文件保留。
- 图表修正前的三机型回归：[run 38708936955](https://github.com/L1angK1NG/StudyTrack/actions/runs/38708936955) 全部通过，每台均为 32 项应用内测试和 4 项 UI 测试。旧库原始 GRDB 夹具由独立核心测试运行，避免托管 App 测试直接依赖数据库驱动的链接符号。
- 图表修正后的最终模拟器回归：[run 38710972087](https://github.com/L1angK1NG/StudyTrack/actions/runs/38710972087) 三台全部通过：iPhone SE（第 3 代）、iPhone 17、iPhone 17 Pro Max，每台均为 32 项应用内测试和 4 项 UI 测试，日志含 `TEST SUCCEEDED`。对应 job 为 116342546851、116342546890、116342546859。
- 已查看最终 iPhone 17 截图，确认同日曲线横向展开、首页最近成绩为最后一条录入记录，分科卡片已移除全科比较提示；个性化页没有旧的用户名预览卡。
- 本地最终截图：[成绩分析](/E:/Project/StudyTrack/artifacts/school-final-screens/analysis.png)、[首页](/E:/Project/StudyTrack/artifacts/school-final-screens/home.png)、[个性化](/E:/Project/StudyTrack/artifacts/school-final-screens/personalization.png)。日志和安装包结构校验结果位于 `artifacts/school-final-*.log`、`artifacts/school-ipa-build24/verification.json`。

## 真机与签名边界

未签名 IPA 需要用户自行签名安装。主应用和 Widget extension 必须使用匹配的 App Group；iCloud Drive 容器也必须由实际签名配置授权。普通编译通过不能证明重签工具保留这些能力。

重新签名时同时签主应用与 `PlugIns/StudyTrackWidgets.appex`，保留匹配的 App Group 与 iCloud 容器授权。主应用 ID 为 `com.repea.studytrack.ios`，扩展 ID 为 `com.repea.studytrack.ios.widgets`，App Group 为 `group.com.repea.studytrack.ios`，容器为 `iCloud.com.repea.studytrack.ios`。

iCloud 不可用会显示可理解的状态，保留本机备份路径；不会自动替换本机数据。云端真正完成上传、跨设备发现与恢复、小组件安装/系统刷新预算、锁屏隐私、复杂壁纸下的可读性和原生玻璃的真机观感，均需要最终签名后的 iPhone 验收。

## Apple API 参考

- [Liquid Glass](https://developer.apple.com/documentation/swiftui/glass)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit)
- [配置 iCloud 服务](https://developer.apple.com/documentation/Xcode/configuring-icloud-services)
- [iCloud 上传状态](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisuploadedkey)
