#!/bin/bash
# Compares the speed of the working tree with a git ref (main by default).
#
#   tools/bench.sh [REF]
#
# It builds REF in a temporary git worktree and the working tree in place,
# then runs each build N times in turns, so that a slow moment of the
# machine hits both. It prints the median of the startup world generation
# time and of the CPU time per frame, and two counts from Spinel that went
# up in each type regression before: the calls to sp_box in the C and the
# --warn-widen warnings in the game code.
#
# N sets the number of runs (default 3), and FRAMES the frames of each run
# (default 900). Each run opens a game window.
set -eo pipefail
cd "$(dirname "$0")/.."
root=$PWD
ref=${1:-main}
runs=${N:-3}
frames=${FRAMES:-900}
if [ -z "$SPINEL" ]; then
  SPINEL=$(command -v spinel || echo "$HOME/Documents/dev/oss/spinel/spinel")
fi
export SPINEL

tmp=$(mktemp -d)
cleanup() {
  git -C "$root" worktree remove --force "$tmp/ref" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT
git worktree add --detach --quiet "$tmp/ref" "$ref"
mkdir "$tmp/run"

# Prints the sp_box count and the warning count of the tree in $1.
spinel_counts() {
  (cd "$1" && "$SPINEL" main.rb -S --warn-widen 2>"$tmp/widen" >"$tmp/c")
  local boxes widen
  boxes=$(grep -o 'sp_box[a-z_]*(' "$tmp/c" | wc -l | tr -d ' ')
  widen=$(grep "warning:" "$tmp/widen" | grep -vc "/builtins/" || true)
  echo "$boxes $widen"
}

echo "building $ref"
"$tmp/ref/build.sh" >/dev/null
echo "building the working tree"
./build.sh >/dev/null
echo "counting boxes and widen warnings"
read -r ref_box ref_widen < <(spinel_counts "$tmp/ref")
read -r cur_box cur_widen < <(spinel_counts "$root")

# Runs the game in $1 once and appends its two numbers to $2.gen and $2.cpu.
bench_once() {
  local out
  out=$(cd "$tmp/run" && NEW=1 MUTE=1 AUTOPILOT=1 NOVSYNC=1 FRAMES=$frames "$1" 2>&1)
  echo "$out" | sed -n 's/^world: generate and mesh .* in \([0-9.]*\) ms$/\1/p' >>"$2.gen"
  echo "$out" | sed -n 's/.*avg_cpu_ms=\([0-9.]*\).*/\1/p' >>"$2.cpu"
}

for i in $(seq "$runs"); do
  echo "run $i of $runs"
  bench_once "$tmp/ref/spinelcraft" "$tmp/ref"
  bench_once "$root/spinelcraft" "$tmp/cur"
done

median() { sort -n "$1" | awk '{ v[NR] = $1 } END { print (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2 }'; }

echo
printf '%-30s %12s %12s\n' "" "$ref" "working tree"
printf '%-30s %12s %12s\n' "world generation ms (median)" "$(median "$tmp/ref.gen")" "$(median "$tmp/cur.gen")"
printf '%-30s %12s %12s\n' "avg_cpu_ms (median)" "$(median "$tmp/ref.cpu")" "$(median "$tmp/cur.cpu")"
printf '%-30s %12s %12s\n' "sp_box calls" "$ref_box" "$cur_box"
printf '%-30s %12s %12s\n' "widen warnings" "$ref_widen" "$cur_widen"
