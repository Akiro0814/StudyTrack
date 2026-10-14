#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 ios/Scripts/probe-environment.py
cd ios
xcodegen generate --spec project.yml
mkdir -p StudyTrack.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp Package.resolved StudyTrack.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
xcodebuild -resolvePackageDependencies -onlyUsePackageVersionsFromResolvedFile -project StudyTrack.xcodeproj -scheme StudyTrack -clonedSourcePackagesDirPath .spm
mkdir -p ../artifacts
cp Package.resolved ../artifacts/Package.resolved
while IFS= read -r device_type; do
  runtime="$(python3 -c 'import json; print(json.load(open("../artifacts/Toolchain.candidate.json"))["runtimeID"])')"
  udid="$(xcrun simctl create StudyTrack-CI "$device_type" "$runtime")"
  cleanup() { xcrun simctl shutdown "$udid" || true; xcrun simctl delete "$udid" || true; }
  trap cleanup EXIT
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b
  xcodebuild test -onlyUsePackageVersionsFromResolvedFile -project StudyTrack.xcodeproj -scheme StudyTrack -destination "platform=iOS Simulator,id=$udid" -resultBundlePath "../artifacts/$udid.xcresult" -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | tee "../artifacts/$udid-xcodebuild.log"
  xcrun simctl io "$udid" screenshot "../artifacts/$udid.png"
  cleanup
  trap - EXIT
done < <(python3 -c 'import json; print("\n".join(json.load(open("../artifacts/Toolchain.candidate.json"))["deviceTypeIDs"]))')
