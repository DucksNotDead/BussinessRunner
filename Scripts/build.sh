#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SDK="$(xcrun --show-sdk-path)"
SWIFTC="${SWIFTC:-$DEVELOPER_DIR/usr/bin/swiftc}"
APP="$ROOT/dist/BussinessRunner.app"
BIN="$APP/Contents/MacOS/BussinessRunner"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/BussinessRunner/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

files=()
while IFS= read -r line; do
  files+=("$line")
done < <(find "$ROOT/BussinessRunner" -name '*.swift' | sort)

"$SWIFTC" -parse-as-library -swift-version 5 \
  -target arm64-apple-macosx26.0 \
  -sdk "$SDK" \
  -O \
  -o "$BIN" \
  "${files[@]}"

echo "built $BIN"
