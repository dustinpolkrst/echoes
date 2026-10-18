#!/bin/sh
# Run the headless checks. Exits nonzero if any of them fails.
LOVE=${LOVE:-love}
GAME="$(dirname "$0")/../game"
for mode in --selftest --flow --slack; do
  echo "== $mode"
  "$LOVE" "$GAME" "$mode" || { echo "FAILED: $mode"; exit 1; }
done
echo "all checks passed"
