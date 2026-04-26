#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
WITH_BUILD="${2:-}"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

check_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Missing required file: ${path#$ROOT/}"
}

check_dir() {
  local path="$1"
  [[ -d "$path" ]] || fail "Missing required directory: ${path#$ROOT/}"
}

check_dir "$ROOT"
check_file "$ROOT/package.json"
check_dir "$ROOT/src/content"
check_file "$ROOT/src/content/splash.json"
check_file "$ROOT/src/content/site.json"
check_dir "$ROOT/src/content/projects"

node -e '
const fs = require("fs");
const path = process.argv[1];
const data = JSON.parse(fs.readFileSync(path, "utf8"));
if (!data.scripts || !data.scripts.dev) {
  console.error("ERROR: package.json must define scripts.dev");
  process.exit(1);
}
' "$ROOT/package.json"

echo "Repo shape check passed"

if [[ "$WITH_BUILD" == "--with-build" ]]; then
  echo "Running npm run build (smoke check)..."
  (cd "$ROOT" && npm run build)
fi

echo "Health check passed"
