#!/bin/bash
# Compiles the game with Spinel. Set SPINEL to the compiler; otherwise it uses
# `spinel` from PATH, then ~/Documents/dev/oss/spinel/spinel.
# `./build.sh` writes ./spinelcraft. `./build.sh test` writes
# ./spinelcraft-test: the game with the self-test and the screenshot switches.
# The old binary goes first, so a failed compile cannot leave it in place.
set -eo pipefail
cd "$(dirname "$0")"
if [ -z "$SPINEL" ]; then
  SPINEL=$(command -v spinel || echo "$HOME/Documents/dev/oss/spinel/spinel")
fi
entry=main.rb
out=spinelcraft
if [ "$1" = "test" ]; then
  entry=test_game.rb
  out=spinelcraft-test
fi
rm -f "$out"
"$SPINEL" "$entry" -o "$out" 2>&1 | { grep -v -e "->" || true; }
test -x "$out"
