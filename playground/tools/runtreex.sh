#!/bin/bash
# This will pass stdin to stdout via treex command of the given scenario.

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

mydir=$(dirname $(readlink -f "$0" ) )
[ -d "$mydir" ] || die "Failed to find ourselves, got: $mydir"

pushd $mydir > /dev/null || die "Failed to chdir to our dir: $mydir"

if [ -e runtreex.treex-step-used ]; then
  STEP=$(cat runtreex.treex-step-used)
else
  STEP=
fi

# Find a done treex step
# (try the selection 10 times, THEN fail, AFS sometimes derps)
TRIES=0
while [ $TRIES -lt 10 -a -z "$STEP" ]; do
    echo "Selecting a DONE treex step, attempt $TRIES" >&2
    STEP=$(cd ..; eman sel t treex d --remote | head -n 1)
    [ ! -z "$STEP" ] || (echo "Waiting for AFS to sync, will try again."; sleep 10)
    TRIES=$(($TRIES+1))
done

[ -z "$STEP" ] \
  && die "There is no appropriate TreeX step. Run 'eman init treex -start' first."

STEPDIR=`eman path $STEP`

[ -n "$STEPDIR" ] || die "$STEPDIR is empty"
[ -d "$STEPDIR" ] || die "$STEPDIR does not exist"

TREEX=$STEPDIR/treex

[ -e $TREEX.bashsource ] || die "$TREEX.bashsource not found"
source $TREEX.bashsource

echo "runtreex: Using this particular treex step: $STEP" >&2
if [ ! -e runtreex.treex-step-used ]; then
  # store for future, so that we're more consistent in treex choice
  echo "$STEP" > runtreex.treex-step-used
fi

popd > /dev/null # go back to the original dir
$TREEX/treex/bin/treex -e WARN "$@"

exit $?
