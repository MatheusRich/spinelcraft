#!/bin/bash
# Measures the cost of the game at several view distances, for the full
# machine and for a slowed CPU, to estimate the minimum requirements.
#
#   tools/lowend.sh
#
# For each view distance it runs ./spinelcraft twice: at normal speed, and
# under `taskpolicy -b` (background priority: the efficiency cores at a low
# clock). It prints the CPU and GPU time per frame, the worst frame and the
# peak resident memory. The resident memory leaves out most of the graphics
# memory: tools/footprint.sh measures what macOS charges to the game. The
# slowed run is an estimate, not a real old computer.
#
# VIEWS sets the view distances (default "200 300 460 1600"; the chunk ring stops growing at 460), FRAMES the
# frames of each run (default 900). Each run opens a game window. Build
# first with ./build.sh.
set -eo pipefail
cd "$(dirname "$0")/.."
views=${VIEWS:-"200 300 460 1600"}
frames=${FRAMES:-900}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Prints "avg_cpu_ms max_frame_ms slow_frames gpu_wait_ms rss_mb" for one run.
# The rest of the arguments are a command prefix, such as taskpolicy -b.
measure() {
  local view=$1
  shift
  (cd "$tmp" && env NEW=1 MUTE=1 AUTOPILOT=1 NOVSYNC=1 GPUTIME=1 VIEW="$view" FRAMES="$frames" \
    /usr/bin/time -l "$@" "$OLDPWD/spinelcraft" >out 2>err) || true
  awk '
    /avg_cpu_ms=/ { for (i = 1; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] } }
    /^gpu_wait_ms=/ { split($0, kv, "="); v["gpu"] = kv[2] }
    END { printf "%s %s %s %s ", v["avg_cpu_ms"], v["max_frame_ms"], v["slow_frames"], v["gpu"] }
  ' "$tmp/out"
  awk '/maximum resident set size/ { printf "%d\n", $1 / 1048576 }' "$tmp/err"
}

printf '%-6s %-10s %8s %8s %8s %8s %8s\n' view cpu avg_cpu max_frame slow gpu_ms rss_mb
for view in $views; do
  for mode in normal slowed; do
    if [ "$mode" = slowed ]; then
      read -r cpu worst slow gpu mb < <(measure "$view" taskpolicy -b)
    else
      read -r cpu worst slow gpu mb < <(measure "$view")
    fi
    printf '%-6s %-10s %8s %8s %8s %8s %8s\n' "$view" "$mode" "$cpu" "$worst" "$slow" "$gpu" "$mb"
  done
done
