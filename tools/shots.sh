#!/bin/sh
# Deterministic screenshots of the real runtime, for spotting any visual or
# behavioural change during a refactor.
#
#   tools/shots.sh <outdir>          render the set into <outdir>
#   tools/shots.sh --compare [ref]   render <ref> (default un-refactored) and
#                                    the working tree, then compare each pair
#
# Each shot is a seeded headless run (fixed 60 Hz clock, no input) started
# by tools/bench_start.rb, so the same code gives byte-identical PNGs. A
# DIFF means the game drew something different at that frame: look at both
# images. BENCH_REF=<ref> renders that commit's app/ instead of the working
# tree (see tools/bench.sh).
set -e
cd "$(dirname "$0")/.."

# name  start  level  frames
SHOTS='
title         title   0  300
1a_start      level   0  400
1b_start      level   1  400
1b_late       level   1  1500
2b_fight      arena   5  700
2d_fight      arena   7  700
2d_fight_late arena   7  2000
end_launch    ending  0  300
end_rise      ending  0  600
end_fireworks ending  0  1200
end_credits   ending  0  2400
'

render() {
  mkdir -p "$1"
  echo "$SHOTS" | while read -r name start level frames; do
    [ -z "$name" ] && continue
    BENCH_START=$start BENCH_SHOT="$1/$name.png" \
      tools/bench.sh "$level" "$frames" 1 >/dev/null
    echo "  $name"
  done
}

if [ "$1" = "--compare" ]; then
  ref=${2:-un-refactored}
  out=$(mktemp -d)
  echo "rendering $ref"
  BENCH_REF=$ref render "$out/ref" >/dev/null
  echo "rendering working tree"
  BENCH_REF= render "$out/new" >/dev/null
  fails=0
  for f in "$out"/ref/*.png; do
    n=$(basename "$f")
    if cmp -s "$f" "$out/new/$n"; then echo "SAME  $n"; else echo "DIFF  $n"; fails=$((fails + 1)); fi
  done
  echo "images in $out (ref/, new/)"
  [ $fails -eq 0 ] && echo "ALL SAME" || { echo "$fails DIFFERENT"; exit 1; }
else
  out=${1:?usage: tools/shots.sh <outdir> | --compare [ref]}
  render "$out"
fi
