#!/usr/bin/env bash
set -euo pipefail

# Builds a distributable, ad-hoc-signed, zipped .app for local/alpha
# distribution (Homebrew cask, manual download). This is NOT App Store
# packaging — no Developer ID signing, no notarization, no App Store Connect
# upload. See docs/app_store_release_checklist.md (once TASK-373 lands) for
# that separate, heavier flow.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

DERIVED_DATA_DIR="${PROJECT_DIR}/build/DerivedData"
DIST_DIR="${PROJECT_DIR}/dist"
APP_NAME="PhalanxDuelClient"

echo "==> Regenerating Xcode project via xcodegen..."
xcodegen generate

echo "==> Building ${APP_NAME} (Release, ad-hoc unsigned build)..."
rm -rf "${DERIVED_DATA_DIR}"
xcodebuild build \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  ENABLE_DEBUG_DYLIB=NO \
  CODE_SIGNING_ALLOWED=NO

BUILT_APP="${DERIVED_DATA_DIR}/Build/Products/Release/${APP_NAME}.app"
if [[ ! -d "${BUILT_APP}" ]]; then
  echo "❌ Build did not produce ${BUILT_APP}" >&2
  exit 1
fi

echo "==> Ad-hoc codesigning (unsigned/unnotarized — alpha distribution only)..."
codesign --force --deep --sign - "${BUILT_APP}"
codesign --verify --verbose "${BUILT_APP}"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${BUILT_APP}/Contents/Info.plist")"
ZIP_NAME="${APP_NAME}-v${VERSION}-macOS.zip"

echo "==> Zipping into dist/${ZIP_NAME}..."
mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${ZIP_NAME}"
ditto -c -k --sequesterRsrc --keepParent "${BUILT_APP}" "${DIST_DIR}/${ZIP_NAME}"

echo "==> ✅ Built ${DIST_DIR}/${ZIP_NAME} (version ${VERSION})"
echo "    This is ad-hoc signed and unnotarized — Gatekeeper will require"
echo "    right-click > Open on first launch unless quarantine is stripped"
echo "    (the Homebrew cask's postflight does this automatically)."
