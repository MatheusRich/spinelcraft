#!/bin/bash
# Samples the memory that macOS charges to the game (`footprint`) while the
# game runs, to see where the memory goes and whether it keeps growing.
#
#   tools/footprint.sh [idle|circle|straight]
#
# idle     the player stays where the world starts
# circle   the autopilot flies in a slow circle (the default)
# straight the autopilot flies in a straight line, so it always meets new chunks
#
# DURATION sets how long the game runs (default 180) and INTERVAL the seconds
# between two samples (default 10). The last line is the growth in MB a minute
# over the second half of the run: a game with no leak ends near zero when it
# stays put. Each run opens a game window. Build first with ./build.sh.
set -eo pipefail
cd "$(dirname "$0")/.."
root=$PWD
mode=${1:-circle}
duration=${DURATION:-180}
interval=${INTERVAL:-10}
case "$mode" in
  idle) autopilot="" ;;
  circle) autopilot=1 ;;
  straight) autopilot=far ;;
  *) echo "mode is idle, circle or straight" >&2; exit 1 ;;
esac
tmp=$(mktemp -d)
pid=
cleanup() {
  [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# Prints one footprint report as "total_mb category=mb ..." for the pid in $1.
sample() {
  footprint "$1" 2>/dev/null | awk '
    function megabytes(value, unit) {
      if (unit == "GB") return value * 1024
      if (unit == "KB") return value / 1024
      if (unit == "B") return value / 1048576
      return value
    }
    /Footprint:/ { total = megabytes($(NF - 5), $(NF - 4)) }
    /^ *[0-9.]+ [KMG]?B +[0-9.]+ [KMG]?B +[0-9.]+ [KMG]?B +[0-9]+ +/ {
      name = $0
      sub(/^ *[0-9.]+ [KMG]?B +[0-9.]+ [KMG]?B +[0-9.]+ [KMG]?B +[0-9]+ +/, "", name)
      dirty[name] += megabytes($1, $2)
    }
    END {
      printf "%d %d %d %d %d %d\n", total,
        dirty["MALLOC_SMALL"], dirty["MALLOC_LARGE"],
        dirty["Owned physical footprint (unmapped) (graphics)"],
        dirty["Owned physical footprint (unmapped)"],
        dirty["IOAccelerator (graphics)"] + dirty["IOSurface"]
    }'
}

(cd "$tmp" && env NEW=1 MUTE=1 ${autopilot:+AUTOPILOT=$autopilot} FRAMES=100000000 \
  "$root/spinelcraft" >out 2>err) &
sleep 3
pid=$(pgrep -n -f "^$root/spinelcraft" || pgrep -n spinelcraft)

printf '%-6s %8s %12s %12s %10s %10s %10s\n' seconds total_mb malloc_small malloc_large gfx_owned unmapped gfx_other
began=$SECONDS
: >"$tmp/totals"
while [ $((SECONDS - began)) -lt "$duration" ]; do
  read -r total small large gfx unmapped other < <(sample "$pid")
  elapsed=$((SECONDS - began))
  printf '%-6s %8s %12s %12s %10s %10s %10s\n' "$elapsed" "$total" "$small" "$large" "$gfx" "$unmapped" "$other"
  echo "$elapsed $total" >>"$tmp/totals"
  sleep "$interval"
done

awk -v half="$((duration / 2))" '
  $1 >= half { n++; sx += $1; sy += $2; sxx += $1 * $1; sxy += $1 * $2 }
  END {
    if (n < 2) exit
    slope = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    printf "growth over the second half: %.1f MB a minute\n", slope * 60
  }' "$tmp/totals"
