# 学迹 iOS

原生 SwiftUI 客户端，目标 iOS 26.0+ / iPhone。业务核心是独立 Swift Package，界面使用系统导航、表单、Swift Charts 与公开 Liquid Glass API。

## 当前验证状态

最新记录见 [`../docs/2026-10-24-platform-validation.md`](../docs/2026-10-24-platform-validation.md)。iOS 1.2.0 build 32 已生成 iphoneos / arm64 Release IPA；最新 CI 在 iPhone SE 3、iPhone 17、iPhone 17 Pro Max 三种模拟器上通过核心、宿主和 UI 测试。真实 iCloud 传输、重签设备上的 WidgetKit / App Group、最低 iOS 26.0 与真机安装仍需分别验证。

## macOS 开发

需要正式 Xcode 26、可用的 iOS 26 模拟器 runtime、Python 3。根目录执行：

```sh
bash ios/Scripts/install-xcodegen.sh
export PATH="$PWD/ios/.tools/xcodegen/bin:$PATH"
python3 ios/Scripts/probe-environment.py
bash ios/Scripts/test-simulator.sh
open ios/StudyTrack.xcodeproj
```

生成器安装脚本会显示实际二进制所在路径；若包内路径与上例不同，将 `find ios/.tools -type f -name xcodegen` 的结果所在目录加入 PATH。GitHub Actions 会自动设置 PATH。

单独运行核心：

```sh
cd ios
swift test
```

Swift 6.1 / Ubuntu 的系统 SQLite 不提供 Apple 平台的 snapshot 链接符号，跨平台检查需关闭未使用的 snapshot API：

```sh
swift test -j 4 -Xswiftc -DGRDBCUSTOMSQLITE
```

此标志只用于 Linux 验证，不加入 Apple 工程。Windows 可运行 `node ios/Scripts/check-contracts.mjs` 验证实际 SQL 约束，需要 Node 24。

## 工具链与依赖

`project.yml` 是 Xcode 工程唯一配置源。不要手改生成的 pbxproj。Swift Package 使用精确版本及真实解析出的 Package.resolved；CI 将锁文件复制到生成工程的 workspace 并禁止自动更新版本。

`ios-environment` 产出环境清单和 `Toolchain.candidate.json`。首次 `ios-ci` 在已安装的 iOS 26 runtime 和可用 iPhone 类型中发现测试目标；根据成功的 xcresult 审核并将实际 Xcode/runtime/deviceType 写回 Toolchain.lock.json。后续不匹配会失败。首次探测与 CI 结果不能代替最低 iOS 26.0 的兼容和真机验证。

## 交换与恢复

- Excel 使用固定 11 列，文本日期、数值分数、可空整数排名；以 `=` 开头的文字不会被写成公式。
- 支持列乱序、稀疏单元格、共享/内联字符串、1900/1904 数值日期；不支持加密、宏、旧 `.xls` 和公式求值。
- 首个 worksheet 为输入工作表。错误有原始行号；日期含时间和未知分类须明确接受后转换。
- 默认错误阻止导入，可明确选择仅导入有效行；重复及内容冲突跳过并报告。提交检查全库 revision，采用单事务，不修改当前选择。
- 完整备份的 JSON 契约见 `shared-spec/backup-v1.schema.json`。替换恢复前校验所有资源、关系与唯一键，保存本机恢复快照，再安装内容寻址的不可变资源，事务替换数据和设置。
- 原恢复快照位于 Application Support/StudyTrack/recovery；不在日常导出中重复嵌套。首版保守保留旧资源和恢复快照，不自动回收，避免删除仍用于恢复的内容。
- Android“数据与备份 → 导出完整备份”生成相同格式；旧版时间戳需确认原时区，新版固定日期不受时区变化影响。历史超精度、归一化重复或无法读取的资源会阻止生成。
- 备份未加密。不要用真实学生数据制作公开测试样本。

## 验证与夹具

Swift 测试涵盖评分、日期、隔离、事务、分页摘要、导入冲突与过期预览、恢复、未知扩展、独立工作簿与 10000 行数据。黄金数据包含 2 用户/4 学期/不同满分/空科目。测试资源均为合成数据。

独立验证依赖只用于开发，不进入 App：

```sh
python3 -m pip install openpyxl jsonschema PyYAML
python3 ios/Scripts/generate-fixtures.py
STUDYTRACK_ARTIFACTS="$PWD/artifacts" swift test --package-path ios
python3 ios/Scripts/validate-artifacts.py
```

POI 互操作使用与 Android 相同的 Apache POI 5.2.3，需要 JDK 17+ 与 Maven：

```sh
mvn -f ios/Scripts/interop/pom.xml org.apache.maven.plugins:maven-dependency-plugin:3.8.1:build-classpath -Dmdep.outputFile=/tmp/studytrack-poi-classpath
java -Dfile.encoding=UTF-8 --class-path "$(cat /tmp/studytrack-poi-classpath)" ios/Scripts/interop/POIInterop.java "$PWD"
```

## 自行签名的 IPA（当前交付路线）

用户指定仓库为 `L1angK1NG/StudyTrack`，没有付费 Apple Developer 账号。`iOS Unsigned IPA` 在 push 或手动执行时编译 **iphoneos / arm64** Release，上传 `StudyTrack-unsigned.ipa` 和 SHA-256 到 Actions artifact，无需 Apple 签名 secrets。

下载 artifact ZIP 并解压后，将里面的 IPA 导入你已有的自签工具，使用自己的证书重签并安装到 iOS 26+ iPhone。该文件尚未签名，不能直接安装；证书有效期、设备登记和重签结果由使用的签名方式决定。本次不会索取你的证书密码或私钥。

macOS 本地生成：`bash ios/Scripts/build-unsigned-ipa.sh`。脚本检查生成物为真机平台及 arm64，并验证 IPA ZIP 结构，不会把模拟器 .app 改扩展名冒充真机包。

## TestFlight（将来可选）

在真实 Git 仓库配置受保护的 `ios-release` environment，并在验证当前 commit 的 iOS CI 后手动触发 `ios-testflight`。环境变量：`APPLE_TEAM_ID`、`BUNDLE_ID`。加密 secrets：`SIGNING_P12_BASE64`、`SIGNING_P12_PASSWORD`、`PROFILE_BASE64`、`ASC_KEY_BASE64`、`ASC_KEY_ID`、`ASC_ISSUER_ID`。工作流不打印密钥，不提交证书；失败也删除临时钥匙串与文件。

当前默认标识 `com.repea.studytrack.ios`；最终标识变更须同步 project.yml、UTType 的导出标识与 document type，以及开发者平台的 App ID/描述文件。上传命令返回成功只表示上传完成，App Store Connect 处理成功、TestFlight 可安装、真机验收分别记录。

发布前必须补充：真机深浅色/玻璃/键盘/返回手势/最大字体/VoiceOver、最低系统、后台恢复、实际性能、隐私报告和 App Store 审核材料。图标从仓库现有 logo.png 制作，需维护者确认原素材授权。
