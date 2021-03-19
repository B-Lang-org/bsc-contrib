#!/usr/bin/env bash

set -e

# For now, restrict to Bluespec code
if git ls-files | egrep '\.(bs|bsv)$' | xargs grep -n ' $'; then
  echo "Trailing whitespace found!"
  exit 1
fi

# Don't allow tabs in BH/Classic code, where formatting matters
if git ls-files | egrep '\.bs$' | xargs grep -n $'\t'; then
  echo "Tabs found!"
  exit 1
fi

exit 0
