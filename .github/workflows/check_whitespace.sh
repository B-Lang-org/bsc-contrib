#!/usr/bin/env bash

set -e

RESULT=0

# -----
# Check for trailing whitespace

# For now, restrict to Bluespec code
CMD="git ls-files | egrep '\.(bs|bsv)$' | xargs grep -H -n -e ' $'"
if [ $(eval "$CMD -l -- | wc -l") -ne 0 ]; then
    eval "$CMD --" || true
    echo "Trailing whitespace found!"
    RESULT=1
fi

# -----
# Check for tabs

# Don't allow tabs in BH/Classic code, where formatting matters
CMD="git ls-files | egrep '\.bs$' | xargs grep -H -n -e $'\t'"
if [ $(eval "$CMD -l -- | wc -l") -ne 0 ]; then
    eval "$CMD --" || true
    echo "Tabs found!"
    RESULT=1
fi

# -----

exit $RESULT
