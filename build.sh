#!/bin/bash
# Compiles the game with Spinel. Set SPINEL to the compiler; otherwise it uses
# `spinel` from PATH, then ~/Documents/dev/oss/spinel/spinel.
# The old binary goes first, so a failed compile cannot leave it in place.
set -eo pipefail
cd "$(dirname "$0")"
if [ -z "$SPINEL" ]; then
  SPINEL=$(command -v spinel || echo "$HOME/Documents/dev/oss/spinel/spinel")
fi
rm -f spinelcraft
"$SPINEL" main.rb -o spinelcraft 2>&1 | { grep -v -e "->" || true; }
test -x spinelcraft
