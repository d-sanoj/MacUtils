#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/MacUtils.app}"
OUTPUT_DIR="${2:-$ROOT_DIR/build_dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at: $APP_PATH" >&2
  echo "Build or place MacUtils.app there, or pass the app path as the first argument." >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH" .app)"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
SIGNING_IDENTITY="${MACUTILS_CODESIGN_IDENTITY:--}"

if [[ -f "$INFO_PLIST" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" 2>/dev/null || true)"
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null || true)"
  EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST" 2>/dev/null || true)"
fi

if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(date +%Y.%m.%d)"
fi

mkdir -p "$OUTPUT_DIR"

STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/${APP_NAME}_staging.XXXXXX")"
VOLUME_NAME="${APP_NAME} ${VERSION}"
DMG_PATH="$OUTPUT_DIR/${APP_NAME}-${VERSION}.dmg"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

STAGED_APP_PATH="$STAGING_DIR/$APP_NAME.app"
STAGED_INFO_PLIST="$STAGED_APP_PATH/Contents/Info.plist"
STAGED_EXECUTABLE_PATH=""

if [[ -f "$STAGED_INFO_PLIST" ]]; then
  STAGED_EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$STAGED_INFO_PLIST" 2>/dev/null || true)"
  if [[ -n "${STAGED_EXECUTABLE_NAME:-}" ]]; then
    STAGED_EXECUTABLE_PATH="$STAGED_APP_PATH/Contents/MacOS/$STAGED_EXECUTABLE_NAME"
  fi
fi

if [[ -n "${BUNDLE_ID:-}" ]]; then
  echo "Signing staged app with identifier: $BUNDLE_ID"
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "Using ad-hoc signing. Accessibility and Screen Recording permissions may need to be re-granted after each rebuilt export."
  fi

  if [[ -n "$STAGED_EXECUTABLE_PATH" && -f "$STAGED_EXECUTABLE_PATH" ]]; then
    codesign --remove-signature "$STAGED_EXECUTABLE_PATH" 2>/dev/null || true
    codesign \
      --force \
      --sign "$SIGNING_IDENTITY" \
      --identifier "$BUNDLE_ID" \
      "$STAGED_EXECUTABLE_PATH"
  fi

  codesign --remove-signature "$STAGED_APP_PATH" 2>/dev/null || true
  codesign \
    --force \
    --deep \
    --sign "$SIGNING_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    "$STAGED_APP_PATH"
fi

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created DMG: $DMG_PATH"
