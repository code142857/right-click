#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

xcodebuild \
  -project RightClick.xcodeproj \
  -scheme RightClick \
  -configuration Release \
  -derivedDataPath .build/xcode \
  -destination 'generic/platform=macOS' \
  "$@" \
  build

printf '\n构建完成：%s/.build/xcode/Build/Products/Release/RightClick.app\n' "$project_dir"
printf '打开应用后，点击「打开系统设置…」启用 Finder 扩展。\n'
