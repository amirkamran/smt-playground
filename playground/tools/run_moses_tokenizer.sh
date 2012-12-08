#!/bin/bash
# This will pass stdin to stdout via moses tokenizer

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

mydir=$(dirname $(readlink -f "$0" ) )
[ -d "$mydir" ] || die "Failed to find ourselves, got: $mydir"


#try the selection 10 times, THEN fail
#(AFS sometimes derps)
TRIES=0
STEP=
while [ $TRIES -lt 10 -a -z "$STEP" ]; do
    STEP=$(cd ..; eman sel t mosesgiza d | head -n 1)
    sleep 10
    TRIES=$(($TRIES+1))
done

STEPDIR=`eman path $STEP`

[ -z "$STEP" ] && die "There is no appropriate mosesgiza step. Run 'eman init mosesgiza -start' first."

[ -n "$STEPDIR" ] || die "$STEPDIR is empty"
[ -d "$STEPDIR" ] || die "$STEPDIR does not exist"


TOKENIZER=$STEPDIR/moses/scripts/tokenizer/tokenizer.perl

echo "run_moses_tokenizer: Using this particular moses step: $STEP" >&2
echo "$STEP" >> run_moses_tokenizer.mosesgiza-step-used
$TOKENIZER "$@"

exit $?
