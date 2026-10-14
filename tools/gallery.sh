#!/bin/bash
# Renders the README screenshots into screenshots/, 1280 pixels wide.
cd "$(dirname "$0")/.."
mkdir -p screenshots
shot() {
  name=$1
  shift
  env FRAMES=${FRAMES:-900} SHOT=/tmp/spinelcraft_gallery.ppm NEW=1 MUTE=1 "$@" ./spinelcraft > /dev/null
  sips -s format png -Z 1280 /tmp/spinelcraft_gallery.ppm --out "screenshots/$name.png" > /dev/null
  echo "screenshots/$name.png"
}
shot landscape CAM=0,72,0,0.6,-0.08
shot far CAM=0,400,0,0.6,-0.35 VIEW=5000
shot sunset TIME=0.485 CAM=200,72,190,-1.57,0.05
shot mobs SHOWMOBS=1 FRAMES=60
shot cave CAM=190.5,10.05,179.5,0.8,-0.45
shot inventory INVENTORY=1
shot blocks SHOWITEMS=1 HAND=44 FRAMES=600
rm -f /tmp/spinelcraft_gallery.ppm
