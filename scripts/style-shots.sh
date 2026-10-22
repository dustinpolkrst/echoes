#!/bin/sh
set -e
OUT=${1:-/opt/cursor/artifacts}
mkdir -p "$OUT"
LOVE=${LOVE:-love}
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

shot() {
  style=$1
  scene=$2
  shift 2
  data=$(mktemp -d)
  if [ "$style" = baseline ]; then
    XDG_DATA_HOME="$data" "$LOVE" "$ROOT/game" --shot "$@" >"$data/log.txt" 2>&1
  else
    XDG_DATA_HOME="$data" "$LOVE" "$ROOT/game" --style "$style" --shot "$@" >"$data/log.txt" 2>&1
  fi
  png=$(find "$data" -name 'shot_*.png' | head -n 1)
  if [ -z "$png" ]; then
    cat "$data/log.txt" >&2
    exit 1
  fi
  cp "$png" "$OUT/$style-$scene.png"
  rm -rf "$data"
}

for style in baseline ink cut photo; do
  shot "$style" title title
  shot "$style" select select 12
  shot "$style" act1 1
  shot "$style" relay 13 250
  shot "$style" pause pause
done
