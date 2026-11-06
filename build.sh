#!/bin/bash
# Compiles the game with Spinel. Set SPINEL to the compiler; otherwise it uses
# `spinel` from PATH, then ~/Documents/dev/oss/spinel/spinel.
# `./build.sh` writes ./spinelcraft. `./build.sh test` writes
# ./spinelcraft-test: the game with the self-test and the screenshot switches.
# `./build.sh release` writes ./spinelcraft as one C unit. It compiles about
# 11 s slower than the parallel parts of the default build, and clang can
# inline across the whole game, so the world generates about 7% faster.
# The old binary goes first, so a failed compile cannot leave it in place.
set -eo pipefail
cd "$(dirname "$0")"
if [ -z "$SPINEL" ]; then
  SPINEL=$(command -v spinel || echo "$HOME/Documents/dev/oss/spinel/spinel")
fi
entry=main.rb
out=spinelcraft
jobs=()
if [ "$1" = "test" ]; then
  entry=test_game.rb
  out=spinelcraft-test
fi
if [ "$1" = "release" ]; then
  jobs=(--jobs=1)
fi
rm -f "$out"
"$SPINEL" "$entry" "${jobs[@]}" -o "$out" 2>&1 | { grep -v -e "->" || true; }
test -x "$out"
