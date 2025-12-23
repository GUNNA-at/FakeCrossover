#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

xcodebuild \
  -project "$ROOT_DIR/FakeCrossover.xcodeproj" \
  -scheme FakeCrossover \
  -configuration Release \
  -derivedDataPath "$ROOT_DIR/build"

echo "Built app at $ROOT_DIR/build/Build/Products/Release/FakeCrossover.app"
