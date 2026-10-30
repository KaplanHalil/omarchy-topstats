#!/usr/bin/env bash
# Regenerate the marketplace preview from a live Omarchy capture.
#
# Usage: preview/build.sh <capture.png>
#
# The capture is a full-screen 1920x1080 shot with the memory panel open and
# TopStats alone in the bar's centre section, so the panel sits at x=755 y=32.
# Needs: chromium, ImageMagick.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
work="$here/.work"

capture=${1:?full-screen capture with the TopStats panel open}

command -v chromium >/dev/null || { echo "chromium is required" >&2; exit 1; }
command -v magick >/dev/null || { echo "ImageMagick (magick) is required" >&2; exit 1; }

mkdir -p "$work"
trap '[[ -f $work/server.pid ]] && kill "$(cat "$work/server.pid")" 2>/dev/null || true' EXIT

if [[ ! -f $work/wallpaper.jpg ]]; then
  cp "$HOME/.local/state/omarchy/current/theme/backgrounds/1-cosmic.jpg" "$work/wallpaper.jpg"
fi

# 460x560 around the bar segment and the panel.
magick "$capture" -crop 460x560+730+0 +repage "$work/shot.png"
cp "$here/poster.html" "$work/poster.html"

port=${PREVIEW_PORT:-8792}
pushd "$work" >/dev/null
python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 &
echo $! > server.pid
popd >/dev/null
sleep 0.5

cd "$work"
chromium --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=1600,1000 \
  --virtual-time-budget=4000 --screenshot=poster2x.png \
  http://127.0.0.1:"$port"/poster.html >/dev/null 2>&1

magick poster2x.png -resize 1600x1000 -strip -define png:compression-level=9 "$repo/preview.png"
echo "wrote preview.png"
