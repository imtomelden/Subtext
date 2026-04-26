#!/usr/bin/env bash
# Debug build + launch. Same flow as the Raycast "Rebuild & Run Subtext" command.
# Set QUIET=1 to silence xcodegen/xcodebuild (for silent Raycast / launcher wrappers).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="$ROOT/Subtext.xcodeproj"
SCHEME="Subtext"
CONFIG="Debug"
APP_NAME="Subtext"

pkill -x "$APP_NAME" 2>/dev/null || true

# Keep the Xcode project in sync with project.yml so fresh files are always compiled.
run_xcodegen() {
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate --quiet
  elif [[ -x "/opt/homebrew/bin/xcodegen" ]]; then
    /opt/homebrew/bin/xcodegen generate --quiet
  else
    echo "⚠️  xcodegen not found on PATH; skipping project regeneration" >&2
  fi
}

run_build() {
  # Ad-hoc sign ("-") the build. We don't rely on signature stability for
  # TCC persistence — the app uses security-scoped bookmarks (set via the
  # first-run NSOpenPanel) so `~/Documents` access survives rebuilds
  # without an Apple Developer team ID.
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination 'generic/platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES \
    build
}

if [[ "${QUIET:-}" == "1" ]]; then
  run_xcodegen >/dev/null 2>&1 || true
  if ! run_build >/dev/null 2>&1; then
    echo "❌ Build failed" >&2
    exit 1
  fi
else
  run_xcodegen
  run_build
fi

# Resolve the exact Debug bundle for this project (find | head can pick a stale/wrong DerivedData folder).
BUILT_PRODUCTS="$(
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / { gsub(/^ +| +$/, "", $2); print $2; exit }'
)"
APP_PATH="${BUILT_PRODUCTS}/${APP_NAME}.app"
if [[ -z "${BUILT_PRODUCTS}" || ! -d "${APP_PATH}" || ! -x "${APP_PATH}/Contents/MacOS/${APP_NAME}" ]]; then
  echo "Could not resolve built ${APP_NAME}.app (BUILT_PRODUCTS_DIR=${BUILT_PRODUCTS:-<empty>})" >&2
  exit 1
fi

open "$APP_PATH"
echo "${APP_NAME} rebuilt and launched"
