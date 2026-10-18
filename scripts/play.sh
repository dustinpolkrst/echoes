#!/bin/sh
# Start the game. Extra arguments go to the game, e.g. play.sh --shot title
LOVE=${LOVE:-love}
exec "$LOVE" "$(dirname "$0")/../game" "$@"
