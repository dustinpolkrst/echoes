#!/usr/bin/env bash
# Fails if content references an image that does not exist, if a built page has a src (an image, a script or
# the game's frame) whose file is missing from the output, or if static/images holds a PNG no page uses.
#
#   bash devblog/tools/check-images.sh
set -euo pipefail

BLOG=$(cd "$(dirname "$0")/.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
fail=0

refs=$(grep -rhoE '(src="|cover: ")images/[^"]+' "$BLOG/content" | sed -E 's/^(src="|cover: ")//' | sort -u)
for ref in $refs; do
	if [ ! -f "$BLOG/static/$ref" ]; then
		echo "missing: content references static/$ref"
		fail=1
	fi
done

while IFS= read -r png; do
	rel=${png#"$BLOG/static/"}
	if ! grep -qx "$rel" <<< "$refs"; then
		echo "unused: static/$rel"
		fail=1
	fi
done < <(find "$BLOG/static/images" -name '*.png' | sort)

hugo --source "$BLOG" --destination "$OUT" --quiet
while IFS= read -r line; do
	page=${line%%:*}
	src=${line#*:src=\"}
	src=${src%\"}
	case $src in
		http://* | https://*) continue ;;
		/*) path="$OUT/${src#/}" ;;
		*) path="$(dirname "$page")/$src" ;;
	esac
	[[ $path == */ ]] && path="${path}index.html"
	if [ ! -f "$path" ]; then
		echo "broken: ${page#"$OUT/"} -> $src"
		fail=1
	fi
done < <(grep -roE 'src="[^"]+"' --include='*.html' "$OUT")

count=$(wc -w <<< "$refs")
if [ "$fail" -ne 0 ]; then
	echo "image check failed"
	exit 1
fi
echo "ok: $count images referenced, all present, none unused, every built src resolves"
