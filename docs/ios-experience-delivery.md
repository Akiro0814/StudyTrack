# iOS 1.1 体验更新交付记录

本页保留 2026-10-14 的交付历史。2026-10-15 的 17 项更新和 build 24 交付，见 [最新更新与验收记录](ios-2026-10-15-update.md)。

本轮需求：修复自选壁纸不显示、同日成绩图表重叠；加入用户头像，重写原生界面与主要录入流程。

## 实现

- 共享 AppCanvas 覆盖导航容器和页面背景，List/Form 隐藏系统底色；简洁和玻璃主题都显示壁纸。内容在照片上使用系统材质，减少透明度时改用实色。
- ExamTimeline 给每场考试独立序号，日期相同也不重叠。分数、班排、年排、区排可切换，支持选择明细，排名反向且只显示整数刻度，缺失不补零。按用户追加要求，连线与面积填充均采用 monotone 平滑插值，保留真实数据点，避免相邻点之间过冲。
- 每位用户可上传、更换、移除头像；首页姓名旁及设置档案入口显示。头像以 512px 降采样资源保存，通过 platformExtensions 与既有 assets 纳入完整备份。
- 首页重构为个人身份、最近成绩、明确的单条/多科入口、学期概览和可编辑的最近记录。
- 无科目时显示创建引导，创建后自动继续单条/批量录入；取消创建不会进入空编辑器。
- 设置加入真实 App 图标、软件中英文名称、动态版本、资料与分区入口；个性化增加即时预览、颜色、质感和壁纸管理。
- 科目、成绩列表、搜索筛选、趋势明细、引导和编辑器统一排版。常用科目可快速填入，分数突出，可选排名展开填写，键盘完成/下一项、草稿和丢弃保护保留。
- 版本提升至 1.1.0，Bundle ID 保持 com.repea.studytrack.ios；既有成绩和 v1 备份契约不变。

## 验证记录

新增测试已先在旧实现上失败：缺少 ExamTimeline 与头像持久化 API。第一轮原生验证中，标准屏和 SE 的 24 项 App/业务测试、4 项 UI 测试通过；Pro Max 发现引导输入框的键盘焦点问题。已改为原生表单、固定底部主操作与键盘下一项路径，并重新运行完整矩阵。

实际截图检查确认壁纸穿透导航/内容背景、头像显示、同日五场考试横向分布。还根据截图修正大字号横排碎行，并把分析概览移到图表之后。平滑曲线使用 [Apple Swift Charts monotone](https://developer.apple.com/documentation/charts/interpolationmethod/monotone)；折线与面积填充采用一致插值。

最终构建来源 commit `42b52ee9adbba32f584d5681eee026faf19cae2b`；[IPA 构建](https://github.com/L1angK1NG/StudyTrack/actions/runs/38583255642) 与[三机型验证](https://github.com/L1angK1NG/StudyTrack/actions/runs/38583255633) 全部通过。iOS 26.5 的 iPhone SE（第 3 代）、iPhone 17、iPhone 17 Pro Max 每台均通过 24 项 App/业务测试和 4 项 UI 测试，日志均有 `TEST SUCCEEDED`；job 分别为 `115918479274`、`115918478788`、`115918479087`。实际截图确认平滑曲线的 1–5 横轴标签完整显示。

IPA 为 **1.1.0 / build 14**，iPhone / iphoneos / arm64，最低 iOS 26.0，Bundle ID `com.repea.studytrack.ios`，3,980,540 字节。已核对 ZIP CRC、Payload、Info.plist 与 Mach-O 文件头。SHA-256：`930a962d5071467f041d7247bf228fb41c2ba80b75588e21865e1e8c6b0f87e8`。

本地交付文件：`E:\Project\StudyTrack\StudyTrack-1.1.0-build14-unsigned.ipa`；通用文件名 `StudyTrack-unsigned.ipa` 同步更新。用户自行重签，保留 Bundle ID 以支持升级数据延续；真机安装仍需用户设备确认。

真实模拟器截图（合成测试数据）：[首页与头像](screenshots/ios-1.1/home.png)、[平滑成绩曲线](screenshots/ios-1.1/analysis.png)、[设置与品牌](screenshots/ios-1.1/settings.png)。

## 验收范围

模拟器检查覆盖小屏、标准屏、大屏、带实际图片资产的壁纸与头像、同日五场考试、缺失排名、深色和最大辅助字号。夹具仅用于 DEBUG 测试，不进入 Release。

自行重签后的用户 iPhone 安装、真实照片/iCloud 下载、大规模数据下的真机内存与主观动效体验，需要设备验收。上传图片通过系统 PhotosPicker 获取，不读取整个照片库。
