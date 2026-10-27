#!/bin/bash
# Runs before each Bash call. For a `git commit`, it runs RuboCop and Reek and
# blocks the commit (exit 2) when either reports an offense.
cd "$CLAUDE_PROJECT_DIR" || exit 0
command=$(ruby -rjson -e 'puts JSON.parse($stdin.read).dig("tool_input", "command").to_s')
case "$command" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac
if ! out=$(mise exec -- rake lint 2>&1); then
  echo "$out" | tail -30 >&2
  echo "RuboCop or Reek reports offenses. Fix them before the commit." >&2
  exit 2
fi
