#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

pkgs=()
for pkg in ca-certificates curl xz-utils xvfb python3 libgl1 libgl1-mesa-dri; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    pkgs+=("$pkg")
  fi
done
if [ "${#pkgs[@]}" -gt 0 ]; then
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
fi

if ! command -v node >/dev/null 2>&1; then
  node_ver=20.20.2
  node_sha=df770b2a6f130ed8627c9782c988fda9669fa23898329a61a871e32f965e007d
  node_tar=$(mktemp)
  curl -fsSL -o "$node_tar" "https://nodejs.org/dist/v${node_ver}/node-v${node_ver}-linux-x64.tar.xz"
  echo "${node_sha}  ${node_tar}" | sha256sum -c -
  sudo tar -xJf "$node_tar" -C /usr/local --strip-components=1 --no-same-owner
  rm -f "$node_tar"
fi

hugo_ver=0.145.0
hugo_sha=f734be717676acdc4f59d7c348e5e45188778f8c4a14022e102b4c3216971658
hugo_out=$(hugo version 2>&1 || true)
if ! printf '%s\n' "$hugo_out" | grep -q "v${hugo_ver}" || ! printf '%s\n' "$hugo_out" | grep -q extended; then
  hugo_deb=$(mktemp --suffix=.deb)
  curl -fsSL -o "$hugo_deb" "https://github.com/gohugoio/hugo/releases/download/v${hugo_ver}/hugo_extended_${hugo_ver}_linux-amd64.deb"
  echo "${hugo_sha}  ${hugo_deb}" | sha256sum -c -
  sudo dpkg -i "$hugo_deb"
  rm -f "$hugo_deb"
fi

love_dir=/opt/love-11.5
love_sha=65a673406431eff7167a15a032bf7a2e4ba50108e091eb7b176465831f9b5e00
love_out=$("$love_dir/AppRun" --version 2>&1 || true)
if ! printf '%s\n' "$love_out" | grep -q 'LOVE 11.5 '; then
  work=$(mktemp -d /var/tmp/love-11.5.XXXXXX)
  curl -fsSL -o "$work/love.AppImage" "https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage"
  echo "${love_sha}  $work/love.AppImage" | sha256sum -c -
  chmod +x "$work/love.AppImage"
  (cd "$work" && ./love.AppImage --appimage-extract)
  sudo rm -rf "$love_dir"
  sudo mv "$work/squashfs-root" "$love_dir"
  rm -rf "$work"
fi

wrapper=$(mktemp)
cat > "$wrapper" <<'EOF'
#!/bin/sh
real=/opt/love-11.5/AppRun
if [ -z "${DISPLAY:-}" ]; then
  exec xvfb-run -a "$real" "$@"
fi
exec "$real" "$@"
EOF
sudo install -m 755 "$wrapper" /usr/local/bin/love
rm -f "$wrapper"

love_out=$(love --version 2>&1)
printf '%s\n' "$love_out" | grep -q 'LOVE 11.5 '
hugo_out=$(hugo version 2>&1)
printf '%s\n' "$hugo_out" | grep -q "v${hugo_ver}"
printf '%s\n' "$hugo_out" | grep -q extended
command -v node >/dev/null
command -v python3 >/dev/null
command -v xvfb-run >/dev/null
