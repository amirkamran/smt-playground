#!/bin/bash
# This will pass stdin to stdout via treex command of the given scenario.

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

mydir=$(dirname $(readlink -f "$0" ) )
[ -d "$mydir" ] || die "Failed to find ourselves, got: $mydir"


#try the selection 10 times, THEN fail
#(AFS sometimes derps)
TRIES=0
STEP=
while [ $TRIES -lt 10 -a -z "$STEP" ]; do
    STEP=$(cd ..; eman sel t treex d | head -n 1)
    sleep 10
    TRIES=$(($TRIES+1))
done



[ -z "$STEP" ] && die "There is no appropriate TreeX step. Run 'eman init treex -start' first."
[ -d "$mydir/../$STEP" ] || die "$STEP is not in $mydir/.."

TREEX=$mydir/../$STEP/treex

[ -e $TREEX.bashsource ] || die "$TREEX.bashsource not found"
source $TREEX.bashsource

echo "runtreex: Using this particular treex step: $STEP" >&2
echo "$STEP" >> runtreex.treex-step-used
$TREEX/treex/bin/treex -e WARN "$@"

exit $?
