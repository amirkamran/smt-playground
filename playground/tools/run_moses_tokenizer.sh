#!/bin/bash
# This will pass stdin to stdout via moses tokenizer

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

mydir=$(dirname $(readlink -f "$0" ) )
[ -d "$mydir" ] || die "Failed to find ourselves, got: $mydir"


STEP=$(cd ..; eman sel t mosesgiza d | head -n 1)


[ -z "$STEP" ] && die "There is no appropriate mosesgiza step. Run 'eman init mosesgiza -start' first."
[ -d "$mydir/../$STEP" ] || die "$STEP is not in $mydir/.."

TOKENIZER=$mydir/../$STEP/moses/scripts/tokenizer/tokenizer.perl

echo "run_moses_tokenizer: Using this particular moses step: $STEP" >&2
echo "$STEP" >> run_moses_tokenizer.mosesgiza-step-used
$TOKENIZER "$@"

exit $?
