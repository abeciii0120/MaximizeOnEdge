#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MaximizeOnEdge"
"$ROOT/scripts/make_app_bundle.sh"
cd "$ROOT"
ditto -ck --rsrc --sequesterRsrc "./$APP_NAME.app" "./$APP_NAME.zip"
echo "Created: $ROOT/$APP_NAME.zip"
