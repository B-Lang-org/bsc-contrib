#!/usr/bin/env bash

set -e

RESULT=0

# -----
# Check for trailing whitespace

# For now, restrict to Bluespec code

# We should at least look for both trailing space (' ') and tab ('\t').
# By using '\s' in the grep pattern, we also check for CR ('\r') and
# LF ('\f').  If we wanted to allow DOS files (that end lines with \r\n)
# then the grep pattern would need to be '( |\t|\f)\r?$' so that we detect
# spaces and tabs that are followed by CR (and thus not fully trailing).

ALLOWFILE=${SCRIPTDIR}/allow_whitespace.pats
CMD="git ls-files | egrep '\.(bs|bsv)$' | xargs grep -H -n -e '\s$'"
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
