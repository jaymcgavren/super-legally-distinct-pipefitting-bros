#!/bin/sh
# Time the real runtime on one level, headless.
#
#   tools/bench.sh <level-index> [frames] [runs]
#
# Copies app/ to a temp dir, appends tools/bench_start.rb (start straight in
# level <level-index>, 0-based: 1-A is 0 ... 2-D is 7), packs it, and runs it
# headlessly <runs> times. Each run prints the time spent in the cart's frame
# call (CartHost#runFrame: the Ruby tick plus the runtime's drawing), measured
# by tools/bench_time.mjs. Wall-clock time of the whole player is useless
# here: its own per-frame overhead is about 3 ms, ten times the game's cost,
# and it varies by more than the whole game costs.
#
#   BENCH_START=arena        (default) every (re)start puts the player inside
#                            Big Rusty's arena, so the fight keeps running
#   BENCH_START=level        the player idles at the level start instead
#   BENCH_START=ending       the ending sequence (level is ignored)
#   BENCH_START=title        the title screen (level is ignored)
#   BENCH_SHOT=path.png      keep the last frame
#   BENCH_REF=<git ref>      time app/ from that commit instead of the working
#                            tree, e.g. BENCH_REF=un-refactored for the baseline
#
# --seed matters: it gives the cart a fixed 16.7 ms frame clock, so every
# frame is exactly one 60 Hz update. Without it the headless player runs
# frames far faster than 60 Hz and the game skips most updates.
#
# The repo's app/ is never modified. bench_start.rb calls Game internals
# (new_game, to_intro, start_ending, the player, arena column and camera
# ivars, @boss, @goal), so update it when those change. It must also still
# build un-refactored. A Ruby exception in the cart makes this script fail.
set -e
cd "$(dirname "$0")/.."
level=${1:?usage: tools/bench.sh <level-index> [frames] [runs]}
frames=${2:-3600}
runs=${3:-3}
start=${BENCH_START:-arena}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
if [ -n "$BENCH_REF" ]; then
  git archive "$BENCH_REF" app | tar -x -C "$tmp"
else
  cp -R app "$tmp/app"
fi
sed -e "s/BENCH_LEVEL/$level/" -e "s/BENCH_START/$start/" tools/bench_start.rb >> "$tmp/app/main.rb"
npx wasmcart pack --wasm main.wasm --assets "$tmp/app" --name bench \
  --width 1280 --height 720 -o "$tmp/bench.wasc" >/dev/null
echo "${BENCH_REF:-working tree}: $start, level $level, $frames frames"
i=0
while [ $i -lt "$runs" ]; do
  node --import ./tools/bench_time.mjs node_modules/wasmcart/bin/wasmcart-play.js \
    "$tmp/bench.wasc" --seed 1 --frames "$frames" --shot "$tmp/last.png" 2>&1 |
    grep -E 'runFrame|exception' > "$tmp/out.txt" || true
  cat "$tmp/out.txt"
  # A Ruby exception means the cart (or the bench_start patch) is broken:
  # its screenshot is just the exception banner, so fail loudly.
  if grep -q exception "$tmp/out.txt"; then
    echo "bench.sh: ruby exception in the cart" >&2
    exit 1
  fi
  i=$((i + 1))
done
[ -n "$BENCH_SHOT" ] && cp "$tmp/last.png" "$BENCH_SHOT"
exit 0
