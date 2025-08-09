#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MaximizeOnEdge"
DIST_NAME="MaximizeOnEdge_Distribution"
"$ROOT/scripts/make_readme.sh"
"$ROOT/scripts/make_app_bundle.sh"
cd "$ROOT"
TMPDIR="$(mktemp -d)"
mkdir -p "$TMPDIR/$DIST_NAME"
cp -R "$APP_NAME.app" "$TMPDIR/$DIST_NAME/"
cp "README_Install_ja.md" "$TMPDIR/$DIST_NAME/"
(
  cd "$TMPDIR" && \
  ditto -ck --sequesterRsrc --keepParent "$DIST_NAME" "$ROOT/$APP_NAME.zip"
)
rm -rf "$TMPDIR"
echo "Created: $ROOT/$APP_NAME.zip (contains $DIST_NAME with app + README)"
