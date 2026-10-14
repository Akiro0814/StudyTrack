#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p artifacts
locked_developer="$(python3 -c 'import json; print(json.load(open("ios/Toolchain.lock.json"))["developerDirectory"] or "")')"
if [ -n "$locked_developer" ]; then export DEVELOPER_DIR="$locked_developer"; fi
python3 - <<'PY'
import json, subprocess
lock=json.load(open('ios/Toolchain.lock.json'))
if lock['xcodeVersion'] and subprocess.check_output(['xcodebuild','-version'],text=True).strip()!=lock['xcodeVersion']:
    raise SystemExit('Xcode differs from Toolchain.lock.json')
PY
xcodebuild -version | tee artifacts/ipa-xcode-version.log
xcrun swift --version > artifacts/ipa-swift-version.log
(cd ios && xcodegen generate --spec project.yml)
mkdir -p ios/StudyTrack.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp ios/Package.resolved ios/StudyTrack.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
xcodebuild build -onlyUsePackageVersionsFromResolvedFile -project ios/StudyTrack.xcodeproj -scheme StudyTrack -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath ios/DerivedData-IPA CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' 2>&1 | tee artifacts/ipa-build.log
app_path='ios/DerivedData-IPA/Build/Products/Release-iphoneos/StudyTrack.app'
test -d "$app_path"
executable="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$app_path/Info.plist")"
platform="$(/usr/libexec/PlistBuddy -c 'Print DTPlatformName' "$app_path/Info.plist")"
test "$platform" = 'iphoneos'
lipo -archs "$app_path/$executable" | grep -w arm64
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/Payload"
ditto "$app_path" "$staging/Payload/StudyTrack.app"
ditto -c -k --keepParent "$staging/Payload" artifacts/StudyTrack-unsigned.ipa
unzip -t artifacts/StudyTrack-unsigned.ipa > artifacts/ipa-zip-check.log
shasum -a 256 artifacts/StudyTrack-unsigned.ipa | tee artifacts/ipa-sha256.txt
python3 - <<'PY'
import json, os
with open('artifacts/ipa-build.json','w') as f:
    json.dump({'sha':os.getenv('GITHUB_SHA'),'build':os.getenv('BUILD_NUMBER','1'),'platform':'iphoneos',
               'architecture':'arm64','signing':'unsigned-requires-user-resigning','minimumIOS':'26.0',
               'deviceInstallation':'not-tested'},f,indent=2)
PY
