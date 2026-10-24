# StudyTrack 两端更新与验证记录

日期：2026-10-24。代码工作目录 `E:\Project\StudyTrack`；Git 交付副本 `E:\Project\StudyTrack-iOS-delivery`，独立分支 `codex/platform-parity-20261024`。测试全部使用合成学生、成绩、头像及壁纸，没有读取或替换真实学习数据库。

## 交付范围

| 项目 | 本轮实现 |
| --- | --- |
| iOS 云备份 | 持久化授权文件夹、撤销授权、协调读写、占位文件下载、下载错误与冲突提示、取消、100 MB 限制、逐文件错误隔离、恢复预览与过期检查。区分“已写入文件夹”和真正的云上传状态。 |
| iOS 小组件 | 优先选择有成绩且最近的科目、稳定排序、失效选择提示、多用户隐私、串行快照发布防止旧任务覆盖新成绩、首次解锁后的文件保护、深链范围检查、刷新及 App Group 诊断帮助。 |
| 引导与界面 | 两端八页完整功能介绍、上一步/进度/翻页、档案设置转场和进入主界面展开动画；iOS 遵循减少动态效果。大字体下调整标题、成绩行和统计布局。 |
| 品牌 | 使用历史已定稿的 B 版蓝色与米白符号，同步 iOS AppIcon/BrandMark、Android 品牌图和自适应启动图标。 |
| Android 学习管理 | 小学/初中/高中/大学及 32 个学期、阶段切换、同阶段科目继承、旧学期归类、科目历史谱系、多用户头像与独立范围。Room 4→5→6 升级保留旧 ID 和成绩。 |
| Android 成绩与分析 | 单条/批量录入、可选三种排名与反思、草稿、编辑、搜索、左滑删除及撤销、同满分多科比较和整个阶段汇总、同日多次考试、排名缺失留空、保留端点和极值的曲线采样。 |
| Android 数据交换 | 严格 XLSX 预览与行号、错误行和转换需明确接受、JSON 导入报告、事务提交及过期预览检查、导出标准 11 列。完整备份与 iOS 格式互通，保存头像、壁纸、外观、UUID、原始时间和未知扩展。恢复前快照及中断后的设置恢复日志。 |
| Android 界面与材质 | 重建首页、科目、分析、设置及其子页、表单、选择器、日历、开关、导航图标；统一 20 dp 页面边距、26 dp 卡片圆角、中文文案、字体级别和四标签结构。实际接入 Kyant Backdrop 的背景采样、模糊、折射、色差及色彩增强。 |
| Android 个性化与小组件 | 系统/浅色/深色、自定义主题色、照片方向修正、壁纸文字对比、玻璃调节与复位；可配置档案/学期/阶段/科目的真实桌面 AppWidget、刷新、隐私和分析深链。Android 不实现 iCloud 或 iOS 锁屏 WidgetKit。 |

实际运行截图：[iOS 首页](screenshots/platform-2026-10-24/ios-home.png)、[Android 玻璃首页](screenshots/platform-2026-10-24/android-home.png)、[Android 系统文件导入预览](screenshots/platform-2026-10-24/android-xlsx.png)、[小屏 1.8 倍字体、深色及键盘](screenshots/platform-2026-10-24/android-small-dark-keyboard.png)。

## 产品与实际操作复查

本轮将发现的问题直接修复，而非仅列建议：

- 首次点击“添加成绩”却没有科目时，先引导创建科目，完成后继续原来的录入操作。
- 小组件默认选到没有成绩的字母排序首科，导致已录入用户仍见空白；已加入失败回归用例，默认改为最近有成绩科目。
- 老的后台快照可能晚于新快照完成，覆盖新成绩；改为按代次串行发布。
- 学习阶段确认框在模拟器中无法可靠出现；改为由待开启阶段驱动的确认警告，三种尺寸均验证。
- 批量、导入和恢复的半途失败可能造成部分数据或范围漂移；改为范围校验、互斥和事务，并保存恢复日志。
- 数据库 INSERT REPLACE 可能把同名科目替换后连带破坏历史；改为 ABORT，重复提示且保留旧成绩。
- 开启新学期、归类旧学期后历史分析可能断开；修复同阶段谱系衔接，避免复制旧成绩。
- 外观复位不能同时覆盖刚切换的用户；复位只修改外观键。非有限玻璃数值被归一化，防止 NaN 进入渲染器。
- 海外旅行后时间戳转成本地日期可能前移一天；新记录保存固定日期，旧记录导出允许确认原始时区。
- 手机照片可能依 EXIF 方向拍摄；导入图像先修正旋转和镜像，再限制尺寸，避免大图内存压力。
- 下方内容和删除按钮曾被悬浮导航覆盖；内容区按实际导航高度保留空间。Android 不再锁定系统 fontScale。
- 首页录入回调曾保留旧科目状态，使已添加科目的用户仍无法打开单条/批量表单；改为读取最新范围状态，并加入两条失败回归。
- 键盘出现后可能覆盖正在填写的分数；调整滚动区与 IME 内边距的顺序，并在焦点、文本和可用高度改变后请求显示字段。验收检查完整字段可见，排除裁剪为零大小矩形的误判。
- Excel 不能把坏日期、坏分数静默变成今天和零分；公式和无效数值拒绝，日期去时间/未知分类分别列出转换说明。
- 旧壁纸 `bizhi.png` 实际为 JPEG，导致 Release 资源编译失败；更正为 `.jpg`，文件字节未变。
- 原生 Files 提供商冷启动可能超过 10 秒；根据实际日志将 UI 测试等待调整到 30 秒，实际文件选择和导入仍完整执行。

## 已执行验证

### iOS

- 最新应用逻辑的 [三尺寸 CI](https://github.com/Akiro0814/StudyTrack/actions/runs/40082734488) 全部成功：iPhone SE 3、iPhone 17、iPhone 17 Pro Max；[前一轮归档](https://github.com/Akiro0814/StudyTrack/actions/runs/40079905976) 同样全通过。每个任务先执行 34 项核心测试，再执行 42 项宿主测试及 10 项 UI 测试；42 项含核心用例，不能当成 86 个互不重复的用例。
- UI 覆盖完整八页引导、首次科目创建后继续录入、编辑/左滑删除、阶段/学期区分、系统 Files 选择真实 XLSX 并导入、壁纸、深色与无障碍字号、小组件帮助及刷新。
- 云文件宿主用例覆盖授权跨实例保留、本地目录写入/列出/读取、取消及超限不留下半个文件。这些证明文件管线，不证明真实 iCloud 服务器传输。
- 已获取 [iphoneos ARM64 Release 构建](https://github.com/Akiro0814/StudyTrack/actions/runs/40078359967)，版本 1.2.0 build 32。IPA 包内主程序与扩展均为真机 ARM64，包含 WidgetKit 扩展及 AppIntents 元数据、文档类型和 iCloud 声明，Release 不含 UI 测试入口。
- 本机再运行 `node ios/Scripts/check-contracts.mjs` 与 `check-school-contracts.mjs` 检查数据库契约。

### Android

- JDK 21.0.12、Gradle 9.5、AGP 8.13.2；SDK Platform 37.0、targetSdk 36、minSdk 29。为 Backdrop 2.0 的依赖要求使用 API 37.0。AGP 对新 SDK 的支持范围提示仍存在，实际编译与 lint 已通过。
- 16 项 JVM 测试成功：32 学期、阶段进度、数值校验、跨时区固定日期、万条采样、备份安全和独立 iOS 黄金夹具、Excel 公式/坏值/排名/1904 日期/转换提示、外观数值归一化。
- Android 10 / API 29 隔离模拟器最终 18 项设备测试成功：10 项仓库/交换集成、1 项数据库升级、1 项 AppWidgetHost、6 项 UI。包含数据库 4→6 真实升级、事务回滚、同名科目保护、用户隔离、完整备份与头像/外观/恢复快照、过期恢复拒绝、导入不切换范围、恢复日志中断恢复、Android 真实 XLSX 读写及独立 iOS 黄金备份恢复再导出，保留 UUID、时间和日期。
- Android 16 / API 36 最终 18 项设备测试全部通过。另在 360×640 dp、系统字体 1.8 倍下验证完整引导、批量/草稿和深色编辑；严格检查完整输入框与保存动作可见，并用实际屏幕触摸保存成功。
- `:app:testDebugUnitTest :app:connectedDebugAndroidTest :app:lintDebug :app:assembleRelease` 于 Android 10 任务整体成功。Lint 无 error；旧界面和依赖仍有警告，没有用忽略全部错误的方式通过。
- 真实 AppWidgetHost 绑定小组件后可见 85.25，删除成绩并请求刷新后更新为空值；该用例通过，非仅单测生成 widget 数据。
- 通过系统 Files 的真实文件选择、预览和导入；Android 10 的 DocumentsUI 无障碍 ACTION_CLICK 未能执行时，测试改为真实屏幕触摸，继续校验应用内导入结果。
- 本机构建最终 Lint 结果为 0 errors / 70 warnings；Debug APK 的 v2 签名校验成功；Release 包排除了调试夹具入口和测试资源。
- [Android 云端构建、Lint 和 16 项单测](https://github.com/Akiro0814/StudyTrack/actions/runs/40100459071) 成功，对应应用代码提交 `52b6a2d`。后续测试适配和交付文档不改变应用逻辑。
- Release 真正安装运行：仅在隔离 Android 10 AVD 中，使用调试证书给 Release 副本签名，完成全新引导、档案、引导创建科目和录入 85.25 分，AndroidRuntime 无崩溃。此副本只用于 QA；交付的 Release 文件仍未签名，不冒充生产证书发行包。证据为 `release-smoke-result.json`、`release-smoke-home.png` 和脚本。

## 构建产物与证据

本地证据根目录：`artifacts/2026-10-24-platform/`。包括原始构建日志、JUnit/lint 报告、Android 模拟器截图、iOS SE xcresult 导出截图及 IPA 解包验证 JSON。原有 build 29 保留。

- iOS `ios-build32/artifacts/StudyTrack-unsigned.ipa`，7,277,932 字节。
- iOS SHA-256：`8e6525ad75787f1d1ef454f367b113c8575383870be4be645343557f26a88d3f`。
- Android Debug：`app/build/outputs/apk/debug/app-debug.apk`，使用开发调试证书，可安装测试。
- Android Release：`app/build/outputs/apk/release/app-release-unsigned.apk`，尚未配置发布证书。
- 便捷文件位于 `artifacts/2026-10-24-platform/deliverables/`，含安装说明、`artifacts.json` 和 `SHA256SUMS.txt`。
- Android Debug SHA-256：`f0403d03d59d6c3eacb7907bb0fe912bf04b8e47fbd94c7a0dd46ac3299e4c9d`，96,195,825 字节。
- Android Release（未签名）SHA-256：`9917b7a7707f04e093c97debd2d1bdc6ca57ae61550520a3f8737d13c8d71f42`，73,953,716 字节。

## 明确未验证的部分

1. 当前主机为 Windows；iOS 编译和 UI 测试来自 macOS Actions，尚未在用户的已签名 iPhone 上安装运行。无签名 IPA 需要自行重签。
2. 真实 iCloud 账号上传、系统下载占位符、离线转联网、跨设备恢复未进行账号实测。授权普通目录测试不能替代这些证明。
3. iOS App Group、iCloud 容器由实际签名的 entitlement 和开发者账号决定。免费重签不能凭代码取得权限；主 App 已提供文件夹授权路径与小组件诊断，但不能宣称所有签名工具都支持 WidgetKit。
4. Android 使用隔离模拟器，未验证真实 OEM 桌面、电池后台策略、真实手机相册或带生产证书的原安装升级。系统文件选择器、系统字体和平台导航区域随系统不同，不能宣称所有设备逐像素一致。
5. 最低 iOS 26.0 尚无独立 runtime / 真机验证；本轮三机型模拟器 runtime 以归档环境清单为准。
6. PM/用户复查与自动化覆盖了上述路径，不能证明软件不存在所有疑难或隐藏 bug。后续异常应以设备、系统、范围和可重现步骤补充回归用例。
