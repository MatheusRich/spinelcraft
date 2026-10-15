#!/bin/bash
# Builds the game and runs the self-test. It prints only the FAIL lines and
# the totals, and its exit status is that of the self-test.
set -eo pipefail
cd "$(dirname "$0")/.."
./build.sh >/dev/null
status=0
out=$(NEW=1 MUTE=1 SELFTEST=1 ./spinelcraft 2>&1) || status=$?
echo "$out" | grep -e "^FAIL " -e "^ALL [0-9]* PASS$" -e "FAILED$" || true
# A crash prints no totals, so show the end of the output.
if [ $status -ne 0 ] && ! echo "$out" | grep -q "FAILED$"; then
  echo "the self-test stopped with status $status:"
  echo "$out" | tail -20
fi
exit $status
