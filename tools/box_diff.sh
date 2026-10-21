#!/bin/bash
# Prints each C function whose count of sp_box calls differs between two
# outputs of `spinel main.rb -S`: the function, the count in the first
# file, and the count in the second.
# Usage: box_diff.sh base.c new.c
set -eo pipefail
count() {
  awk '
    /^[a-zA-Z].*\) \{$/ {
      if (fn != "") print c, fn
      match($0, /sp_[A-Za-z0-9_]+\(/)
      fn = substr($0, RSTART, RLENGTH - 1)
      c = 0
      next
    }
    { c += gsub(/sp_box/, "&") }
    END { print c, fn }
  ' "$1" | awk '$1 > 0' | sort -k2
}
join -1 2 -2 2 -a1 -a2 -e0 -o 0,1.1,2.1 <(count "$1") <(count "$2") | awk '$2 != $3'
