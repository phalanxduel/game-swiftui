#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "==> Regenerating Xcode project via xcodegen..."
cd "${PROJECT_DIR}"
xcodegen generate

echo "==> Verifying macOS app build..."
xcodebuild -project PhalanxDuelClient.xcodeproj -scheme PhalanxDuelClient build

echo "==> ✅ App build verification passed cleanly."
