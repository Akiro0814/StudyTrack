#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .tools
readarray_compat() { python3 -c 'import json; d=json.load(open("Toolchain.lock.json"))["xcodegen"]; print(d["url"]); print(d["sha256"]); print(d["version"])'; }
values="$(readarray_compat)"
url="$(printf '%s\n' "$values" | sed -n '1p')"
checksum="$(printf '%s\n' "$values" | sed -n '2p')"
version="$(printf '%s\n' "$values" | sed -n '3p')"
curl --fail --location --retry 3 "$url" -o .tools/xcodegen.zip
printf '%s  %s\n' "$checksum" .tools/xcodegen.zip | shasum -a 256 -c -
unzip -q -o .tools/xcodegen.zip -d .tools
binary="$(find .tools -type f -name xcodegen | head -n 1)"
test -n "$binary"
chmod +x "$binary"
"$binary" --version | grep -F "$version"
if [ -n "${GITHUB_PATH:-}" ]; then dirname "$(pwd)/$binary" >> "$GITHUB_PATH"; fi
