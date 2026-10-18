#!/usr/bin/env bash
# Regenerates every screenshot in devblog/static/images from the commits the posts describe.
#
#   bash devblog/tools/shots.sh            all shots
#   bash devblog/tools/shots.sh 03-puzzles only the shots for one post folder
#
# Each commit is exported with `git archive` to $TEMP/echoes-blogshots/<commit>, its conf.lua is
# rewritten to the identity blogshot-<commit> so the player's real save (identity 'echoes') is
# never opened, and LOVE runs that commit's own --shot mode. LOVE wants a short relative game
# path, so it runs from the export's parent with the folder name as the argument.
set -euo pipefail

LOVE=${LOVE:-"/c/Program Files/LOVE/lovec.exe"}
TOOLS=$(cd "$(dirname "$0")" && pwd)
BLOG=$(dirname "$TOOLS")
REPO=$(git -C "$BLOG" rev-parse --show-toplevel)
WORK=$(cygpath -u "${TEMP:-$LOCALAPPDATA/Temp}")/echoes-blogshots
ONLY=${1:-}

# post-folder  commit  output-name  --shot arguments
SHOTS='
01-pitch      a72332d  title-first-build       0
01-pitch      a72332d  wake-first-build        1
01-pitch      a72332d  first-echo-holding      2 330
01-pitch      a72332d  stairway-step           3 270
01-pitch      a72332d  two-minds               4 480
01-pitch      a72332d  ascent                  5 300
02-controls   1b2f9ce  hints-keyboard          1
02-controls   1b2f9ce  hints-gamepad           padhints 1
03-puzzles    10d1344  other-side-mirror       6 200
03-puzzles    10d1344  trapdoor-crumble        7 240
03-puzzles    10d1344  undertow-veil           8 190
03-puzzles    10d1344  underfoot-door          9 330
03-puzzles    10d1344  short-memory            11 226
03-puzzles    10d1344  confluence              12 520
03-puzzles    10d1344  select-three-acts       select 12
04-interface  86d2d95  title-ui-pass           title
04-interface  86d2d95  hud-in-play             2
04-interface  86d2d95  pause                   pause
04-interface  86d2d95  select-ui-pass          select 3
04-interface  86d2d95  settings                settings
04-interface  86d2d95  clear-card              clear 1
04-interface  86d2d95  iris-transition         transition
05-bench      a53d252  pause-before-fix        pause
05-bench      af3114f  pause-after-fix         pause
06-review     e865580  pause-settings-before   pausesettings 3
06-review     1b2f9ce  pause-settings-after    pausesettings 3
06-review     042d3bf  title-up-before         titleup
06-review     1b2f9ce  title-up-after          titleup
06-review     1b2f9ce  quit-confirm            quitonce
07-ferry      1b2f9ce  ferry-start             10
07-ferry      1b2f9ce  ferry-turn-back         10 200
07-ferry      1b2f9ce  ferry-cast              10 280
07-ferry      1b2f9ce  ferry-boarding          10 340
07-ferry      1b2f9ce  ferry-across            10 420
07-ferry      1afca9f  ferry-new-wait          10 150
07-ferry      1afca9f  ferry-new-cast          10 330
07-ferry      1afca9f  ferry-new-ride          10 400
07-ferry      1afca9f  ferry-new-across        10 450
08-next       1b2f9ce  select-ferry-next       select 9
09-layout     1afca9f  select-flat-folder      select 12
09-layout     eccb521  select-game-folder      select 12
'

game_dir() {
	if [ -f "$WORK/$1/main.lua" ]; then echo "$1"; else echo "$1/game"; fi
}

export_commit() {
	local commit=$1 dir
	rm -rf "${WORK:?}/$commit"
	mkdir -p "$WORK/$commit"
	git -C "$REPO" archive "$commit" | tar -x -C "$WORK/$commit"
	dir="$WORK/$(game_dir "$commit")"
	sed -i "s/t\.identity = 'echoes'/t.identity = 'blogshot-$commit'/" "$dir/conf.lua"
	if grep -q "'echoes'" "$dir/conf.lua" || ! grep -q "blogshot-$commit" "$dir/conf.lua"; then
		echo "refusing to run $commit: identity rewrite failed" >&2
		exit 1
	fi
	if [ -f "$dir/shot.lua" ]; then
		mv "$dir/shot.lua" "$dir/shot_base.lua"
		cp "$TOOLS/blogscenarios.lua" "$dir/blogscenarios.lua"
		cat > "$dir/shot.lua" <<-'LUA'
			local Shot = require 'shot_base'
			local base = Shot.setup
			function Shot.setup(Scenes, target, arg)
			  local scenario = require('blogscenarios')[target]
			  if scenario then return scenario(Scenes, arg) end
			  return base(Scenes, target, arg)
			end
			return Shot
		LUA
	fi
}

declare -A exported=()
count=0
while read -r post commit name args; do
	[ -z "$post" ] && continue
	[ -n "$ONLY" ] && [ "$ONLY" != "$post" ] && continue
	if [ -z "${exported[$commit]:-}" ]; then
		export_commit "$commit"
		exported[$commit]=1
	fi
	# shellcheck disable=SC2086
	out=$(cd "$WORK" && "$LOVE" "$(game_dir "$commit")" --shot $args 2>&1) || { echo "$out" >&2; exit 1; }
	src=$(printf '%s\n' "$out" | sed -n 's/^SHOT //p' | tr -d '\r' | tail -n 1)
	if [ -z "$src" ] || [[ "$src" != *"/blogshot-$commit/"* ]]; then
		echo "no shot from $commit --shot $args:" >&2
		echo "$out" >&2
		exit 1
	fi
	mkdir -p "$BLOG/static/images/$post"
	cp "$(cygpath -u "$src")" "$BLOG/static/images/$post/$name.png"
	echo "$post/$name.png  <-  $commit --shot $args"
	count=$((count + 1))
done <<< "$SHOTS"
echo "$count shots"

# Posts claim some pairs are pixel-identical. The named commit's own --diff checks each one and fails the run if not.
diff_pair() {
	local post=$1 commit=$2 a=$3 b=$4 save
	[ -z "$ONLY" ] || [ "$ONLY" = "$post" ] || return 0
	[ -n "${exported[$commit]:-}" ] || export_commit "$commit"
	save=$(cygpath -u "$APPDATA")/LOVE/blogshot-$commit
	mkdir -p "$save"
	cp "$BLOG/static/images/$post/$a.png" "$save/before.png"
	cp "$BLOG/static/images/$post/$b.png" "$save/after.png"
	(cd "$WORK" && "$LOVE" "$(game_dir "$commit")" --diff before.png after.png) | grep '^DIFF'
}

# Post 05: the pause fix left the picture unchanged. Post 09: moving the files changed no pixel.
diff_pair 05-bench af3114f pause-before-fix pause-after-fix
diff_pair 09-layout eccb521 select-flat-folder select-game-folder
