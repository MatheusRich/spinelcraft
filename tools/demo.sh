#!/bin/bash
# Builds the game, records the demo reel (DEMO=1) and makes a video of about
# a minute, with the logo at the start and a music track under it.
# Usage: tools/demo.sh [out.mp4]. TRACK=file picks another track of
# assets/music. It needs ffmpeg. It does not read or change world.sav.
set -eo pipefail
cd "$(dirname "$0")/.."
out=${1:-demo.mp4}
track=assets/music/${TRACK:-DarkReaven-calmed_cube.ogg}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
./build.sh >/dev/null

# The game writes each frame to a named pipe, and ffmpeg reads them from it.
# The PPM parser of ffmpeg sometimes takes pixels for a header and says
# "Invalid maxval". It finds the next frame, and no frame goes missing, so
# those lines do not show.
mkfifo "$work/frames"
ffmpeg -loglevel error -f ppm_pipe -framerate 30 -i "$work/frames" \
  -vf scale=1280:720 -c:v libx264 -crf 16 -pix_fmt yuv420p "$work/reel.mp4" \
  2> >(grep -v -e "Invalid maxval" -e "Last message repeated" >&2) &
encoder=$!
DEMO=1 MUTE=1 NOVSYNC=1 RECORD="$work/frames" ./spinelcraft >/dev/null
wait $encoder

seconds=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$work/reel.mp4")
end=$(echo "$seconds - 2" | bc)
ffmpeg -loglevel error -y -i "$work/reel.mp4" -loop 1 -i assets/logo.png -i "$track" -filter_complex \
  "[1:v]scale=900:-1,format=rgba,fade=in:st=0.5:d=1:alpha=1,fade=out:st=4:d=1:alpha=1[logo];
   [0:v][logo]overlay=(W-w)/2:H/5:shortest=1,fade=in:d=1,fade=out:st=$end:d=2[v];
   [2:a]afade=in:d=1,afade=out:st=$end:d=2[a]" \
  -map "[v]" -map "[a]" -t "$seconds" -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p \
  -c:a aac -b:a 160k -movflags +faststart "$out"
echo "$out"
