#!/bin/bash
# Renders FRAMES frames, saves the last one as a PNG. Usage: tools/shot.sh out.png [env...]
cd "$(dirname "$0")/.."
out=$1
shift
env FRAMES=${FRAMES:-90} SHOT=/tmp/spinelcraft_shot.ppm "$@" ./spinelcraft
sips -s format png /tmp/spinelcraft_shot.ppm --out "$out" > /dev/null
