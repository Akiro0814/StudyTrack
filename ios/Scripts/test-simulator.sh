#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 ios/Scripts/probe-environment.py
export DEVELOPER_DIR="$(python3 -c 'import json; print(json.load(open("artifacts/Toolchain.candidate.json"))["developerDirectory"])')"
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
  cleanup() {
    if [ -d "../artifacts/$udid.xcresult" ]; then
      xcrun xcresulttool export attachments --path "../artifacts/$udid.xcresult" --output-path "../artifacts/screenshots-$udid" || true
    fi
    xcrun simctl shutdown "$udid" || true
    xcrun simctl delete "$udid" || true
  }
  trap cleanup EXIT
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b
  test_selection=()
  if [ "${STUDYTRACK_TEST_TARGET:-all}" = "unit" ]; then
    test_selection=(-only-testing:StudyTrackTests)
  fi
  xcodebuild test "${test_selection[@]}" -onlyUsePackageVersionsFromResolvedFile -clonedSourcePackagesDirPath .spm -project StudyTrack.xcodeproj -scheme StudyTrack -destination "platform=iOS Simulator,id=$udid" -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -test-timeouts-enabled YES -default-test-execution-time-allowance 90 -maximum-test-execution-time-allowance 180 -resultBundlePath "../artifacts/$udid.xcresult" -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO 2>&1 | tee "../artifacts/$udid-xcodebuild.log"
  xcrun simctl io "$udid" screenshot "../artifacts/$udid.png"
  cleanup
  trap - EXIT
done < <(python3 -c 'import json,os; ids=json.load(open("../artifacts/Toolchain.candidate.json"))["deviceTypeIDs"]; selected=os.getenv("STUDYTRACK_DEVICE_TYPE"); assert not selected or selected in ids; print(selected if selected else "\n".join(ids))')
