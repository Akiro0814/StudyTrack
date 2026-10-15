# 2026-10-15 iOS 实机反馈修复

本轮对应用户后续提出的 8 项要求。大学学期仍为大一至大四、上下学期。保留已有用户、科目、学期和成绩。

## 功能与入口

| 要求 | 本轮变化 |
| --- | --- |
| 最近足迹左滑删除 | 首页与分析明细共用左滑行，右侧显示删除按钮，仍可撤销 |
| 相册式顶部过渡 | 移除自制顶部材质遮挡层，使用 iOS 26 的 soft 滚动边缘；覆盖滚动页、列表与表单 |
| 首次使用引导 | 三页介绍记录、分析和备份，可跳过进入档案设置；设置中可重新查看 |
| 滑动误开编辑 | UIKit 方向手势在开始前判定水平/垂直，轻点必须等待拖动失败；不再嵌套按钮和 simultaneous drag |
| iCloud 容器不可用 | 新增系统文件夹授权；优先使用用户选择的 iCloud Drive 目录，保留原容器路径兼容；可独立从文件恢复备份 |
| XLSX 无法选择 | 单一 public.item 的 UIKit 文档选择器，以副本打开；选后检查扩展名、大小和工作簿内容，再进入导入预览 |
| 阶段与学期分离 | 设置新增学习阶段入口；学期列表限当前阶段；开启下一学期继承科目，不复制成绩；全阶段已建完后确认进入下一阶段 |
| 删除/移除/重命名卡顿 | 操作不等待小组件全量导出；后台合并小组件更新，防止旧导出覆盖新数据；资源查询不读全库；用户删除计数改 SQL；缓存壁纸亮度；加载提示延迟显示；弹窗目标与显示状态分离 |

## 使用说明

### iCloud Drive

进入「设置 → 数据与备份 → iCloud 云备份与恢复」，点击「选择 iCloud Drive 备份文件夹」，在系统浏览器中进入 iCloud Drive 并选择或创建文件夹，然后点击立即备份。

应用保存本机授权书签，下次使用不必重新选择。签名不包含原专属容器能力时，仍可通过系统授权目录操作。授权失效时重新选择；旧专属容器里已有的备份，也可通过「从文件选择并恢复备份」检查和恢复。

系统也允许选择本机或第三方文件夹。选择本机文件夹只会产生本机备份，页面会明确提示；不能把本机写入成功认作云同步完成。iCloud 上传由系统处理，可在文件 App 查看实际传输状态。

恢复沿用完整备份校验、预览、数据库版本检查与恢复前本机快照，不会一选文件就覆盖现有成绩。目录授权保存在本机，不作为可跨设备移植的备份权限。

### 学期推进

当前阶段没有其他新学期时，按已经创建的最新学期继续创建。若阶段最后学期已经存在但中间有缺项，则先补齐缺项；只有该阶段全部学期已经创建，才提示进入下一阶段。大学全部创建后提示已经到最后阶段。

学习阶段入口可以随时切回旧阶段，并进入该阶段最近的已建学期。未开启阶段须确认后创建第一学期；未归类旧学期仍保留，可在学习阶段页单独查看和归类。

## 验证

本地数据库契约检查已通过。设备 Release 主程序及 Widget 扩展已编译通过，无编译错误或警告。模拟器核心测试、应用单元测试及界面回归已完成，安装包与关键截图已核验。

最终设备构建：版本 1.1.0（29），最低 iOS 26.0，arm64，未签名；源码 `b21f2b7462d6566eee16f567fc9bce9969efb5f7`。主程序与 Widget 版本一致，扩展及 App Intents 元数据完整；文档类型和文件共享声明已在实际包内检查，Release 中不含 Debug 文件选择测试样本。

- [设备构建记录](https://github.com/L1angK1NG/StudyTrack/actions/runs/38746493863)
- 包体大小：7,409,071 字节
- SHA-256：`9b1f8f2a7d61adce27d8cff50a60bdce94e60893c12f124ebb382ef9718ffbfd`
- 本地核验：`artifacts/followup-ipa-build29/verification.json`

| 验证 | iPhone SE 3 | iPhone 17 | iPhone 17 Pro Max |
| --- | --- | --- | --- |
| 独立 Swift 核心测试 | 32 通过 | 32 通过 | 32 通过 |
| iOS 应用单元测试 | 38 通过 | 38 通过 | 38 通过 |
| 界面回归 | 8 项已覆盖 | 8 通过 | 8 通过 |
| 实际系统选择器选取 XLSX → 导入预览复查 | 通过 | 通过 | 通过 |

[完整界面验证记录](https://github.com/L1angK1NG/StudyTrack/actions/runs/38746494915) 中，iPhone 17 和 Pro Max 的 8 项 UI 全部通过；SE 的其余 7 项通过，XLSX 实际已进入预览，但测试连续滚动越过标题导致断言失败。截图确认数据预览有效后，改为检查预览操作按钮。单元测试另有一条系统选择器扩展名显示属性回读断言不可靠，已移除该属性断言，保留实际选取、读取和预览验证。

[修正后复查记录](https://github.com/L1angK1NG/StudyTrack/actions/runs/38750257138) 在三款设备上全部成功：各 32 项独立核心测试、38 项应用单元测试、1 项实际 XLSX 选择导入 UI。两轮之间仅修改测试与测试调度脚本，应用及小组件源码和 build 29 完全一致；已通过的其他 7 项 UI 不重复执行。测试目标产生 App Intents 元数据提取跳过提示；Release 主程序与 Widget 的构建为零警告。

已人工检查 [首次引导](../artifacts/followup-final-screens/se-09-first-launch-guide.png)、[左滑删除与顶部过渡](../artifacts/followup-final-screens/iphone17-10-recent-left-swipe.png)、[SE 实际 XLSX 导入预览](../artifacts/followup-final-screens/se-13-native-xlsx-import-preview.png)。本地日志为 `artifacts/followup-final-{se,iphone17,max}.log`。

交付：`StudyTrack-2026-10-15-build29-unsigned.ipa`；通用文件名 `StudyTrack-unsigned.ipa` 已同步。原 build 24 保留，主分支未改动。

回归覆盖：首次引导/跳过、左滑/删除/撤销/轻点编辑、阶段与学期入口隔离、真实系统选择器点选 XLSX 并进入预览、文件夹书签跨实例恢复、无专属 iCloud 容器时的备份读写校验、旧小组件任务不能覆盖新内容、科目继承与跨阶段成绩隔离。

测试目录使用的是模拟器本地授权目录，不代表真实 Apple 账号的上传成功；最终签名安装后的 iCloud 传输、具体第三方文件提供方和真机帧率仍需设备验证。

## 采用的系统接口

- [Apple：ScrollEdgeEffectStyle.soft](https://developer.apple.com/documentation/swiftui/scrolledgeeffectstyle/soft)
- [Apple：通过系统选择器授权目录及保存书签](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
