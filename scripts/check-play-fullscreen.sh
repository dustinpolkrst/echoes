#!/bin/sh
# Browser check for the Play page Fullscreen button.
# Fails if the button cannot leave fullscreen, or if Esc leaves the page fullscreen up.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CACHE=${TMPDIR:-/tmp}/echoes-play-fullscreen-check
if [ ! -d "$CACHE/node_modules/puppeteer-core" ]; then
  mkdir -p "$CACHE"
  npm install --prefix "$CACHE" --silent --no-audit --no-fund puppeteer-core@24.15.0
fi
export NODE_PATH="$CACHE/node_modules${NODE_PATH:+:$NODE_PATH}"
exec node "$ROOT/scripts/check-play-fullscreen.mjs"
