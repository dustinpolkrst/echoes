#!/usr/bin/env bash
# Builds the browser version of the game with love.js (LÖVE 11.4 compiled to WebAssembly).
#
#   bash scripts/build-web.sh [out-dir]      default out-dir: build/web
#
# The game is packed without dev/ and with conf.lua's version set to 11.4, the runtime love.js ships, so the
# browser shows no compatibility alert. Compatibility mode (-c) runs without threads, so the page needs no
# cross-origin isolation headers and works on GitHub Pages. web/index.html replaces love.js's own page.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-"$REPO/build/web"}
LOVEJS_VERSION=11.4.1
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/game"
(cd "$REPO/game" && tar --exclude=./dev -cf - .) | tar -xf - -C "$WORK/game"
# The canvas stays 960x540 (not resizable) and the page scales it, so the game draws at exactly 2x in any frame.
sed -i "s/t\.version = '11\.5'/t.version = '11.4'/; s/t\.window\.resizable = true/t.window.resizable = false/" "$WORK/game/conf.lua"
grep -q "t.version = '11.4'" "$WORK/game/conf.lua" && grep -q "t.window.resizable = false" "$WORK/game/conf.lua"   || { echo "conf.lua rewrite failed" >&2; exit 1; }
PY=
for c in python3 python; do "$c" -c 'import zipfile' 2>/dev/null && PY=$c && break; done
[ -n "$PY" ] || { echo "python is needed to zip the game" >&2; exit 1; }
(cd "$WORK/game" && "$PY" -c "
import os, zipfile
with zipfile.ZipFile('../echoes.love', 'w', zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk('.'):
        for name in files:
            path = os.path.join(root, name)
            z.write(path, os.path.relpath(path, '.'))
")

# Run love.js through node: on Windows a bare `love.js` command opens Windows Script Host instead.
(cd "$WORK" && npm init -y >/dev/null && npm install --silent --no-audit --no-fund "love.js@$LOVEJS_VERSION")
node "$WORK/node_modules/love.js/index.js" -c -t Echoes "$WORK/echoes.love" "$WORK/out"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$WORK/out/game.data" "$WORK/out/game.js" "$WORK/out/love.js" "$WORK/out/love.wasm" "$OUT/"
cp "$REPO/web/index.html" "$OUT/index.html"
echo "web build in $OUT"
