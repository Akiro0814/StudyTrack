#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${APPLE_TEAM_ID:?Missing Apple team}" "${BUNDLE_ID:?Missing Bundle ID}" "${BUILD_NUMBER:?Missing build number}"
: "${SIGNING_P12_BASE64:?}" "${SIGNING_P12_PASSWORD:?}" "${PROFILE_BASE64:?}" "${ASC_KEY_BASE64:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || exit 1
mkdir -p artifacts
locked_developer="$(python3 -c 'import json; print(json.load(open("ios/Toolchain.lock.json"))["developerDirectory"] or "")')"
if [ -n "$locked_developer" ]; then export DEVELOPER_DIR="$locked_developer"; fi
private_dir="$(mktemp -d)"
keychain="$private_dir/signing.keychain-db"
key_password="$(openssl rand -hex 32)"
profile_path=""
api_dir="$HOME/.appstoreconnect/private_keys"
api_path="$api_dir/AuthKey_$ASC_KEY_ID.p8"
test ! -e "$api_path" # Never overwrite an existing key.
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  if [ -n "$profile_path" ]; then rm -f "$profile_path"; fi
  rm -f "$api_path"
  rm -rf "$private_dir"
}
trap cleanup EXIT
printf '%s' "$SIGNING_P12_BASE64" | base64 --decode > "$private_dir/cert.p12"
printf '%s' "$PROFILE_BASE64" | base64 --decode > "$private_dir/profile.mobileprovision"
security cms -D -i "$private_dir/profile.mobileprovision" > "$private_dir/profile.plist"
profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "$private_dir/profile.plist")"
profile_name="$(/usr/libexec/PlistBuddy -c 'Print Name' "$private_dir/profile.plist")"
profile_candidate="$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.mobileprovision"
test ! -e "$profile_candidate"
profile_path="$profile_candidate"
mkdir -p "$(dirname "$profile_path")" "$api_dir"
cp "$private_dir/profile.mobileprovision" "$profile_path"
security create-keychain -p "$key_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$key_password" "$keychain"
security import "$private_dir/cert.p12" -P "$SIGNING_P12_PASSWORD" -A -t cert -f pkcs12 -k "$keychain" >/dev/null
security set-key-partition-list -S apple-tool:,apple: -k "$key_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
printf '%s' "$ASC_KEY_BASE64" | base64 --decode > "$api_path"
chmod 600 "$api_path"
export PROFILE_NAME="$profile_name"
python3 - <<'PY'
import os, plistlib
options = {'method':'app-store-connect','teamID':os.environ['APPLE_TEAM_ID'],'signingStyle':'manual',
           'provisioningProfiles':{os.environ['BUNDLE_ID']:os.environ['PROFILE_NAME']},'uploadSymbols':True}
with open('artifacts/ExportOptions.plist','wb') as f: plistlib.dump(options,f)
PY
(cd ios && xcodegen generate)
mkdir -p ios/StudyTrack.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp ios/Package.resolved ios/StudyTrack.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
xcodebuild archive -onlyUsePackageVersionsFromResolvedFile -project ios/StudyTrack.xcodeproj -scheme StudyTrack -configuration Release -destination 'generic/platform=iOS' -archivePath artifacts/StudyTrack.xcarchive DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' PROVISIONING_PROFILE_SPECIFIER="$profile_name" OTHER_CODE_SIGN_FLAGS="--keychain $keychain" 2>&1 | tee artifacts/archive.log
xcodebuild -exportArchive -archivePath artifacts/StudyTrack.xcarchive -exportPath "$private_dir/export" -exportOptionsPlist artifacts/ExportOptions.plist 2>&1 | tee artifacts/export.log
ipa="$(find "$private_dir/export" -maxdepth 1 -name '*.ipa' -print -quit)"
test -n "$ipa"
xcrun iTMSTransporter -m upload -assetFile "$ipa" -apiKey "$ASC_KEY_ID" -apiIssuer "$ASC_ISSUER_ID" 2>&1 | tee artifacts/upload.log
python3 - <<'PY'
import json, os
with open('artifacts/release.json','w') as f:
    json.dump({'sha':os.getenv('GITHUB_SHA'),'build':os.environ['BUILD_NUMBER'],'bundleID':os.environ['BUNDLE_ID'],
               'upload':'command-completed','testflightInstall':'requires-App-Store-Connect-processing-and-device-validation'},f,indent=2)
PY
