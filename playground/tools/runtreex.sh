#!/bin/bash
# This will pass stdin to stdout via treex command of the given scenario.

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

mydir=$(dirname $(readlink -f "$0" ) )
[ -d "$mydir" ] || die "Failed to find ourselves, got: $mydir"

[ -e $mydir/runtreex.use-this-treex-step ] \
|| die "Please put your desired s.treex.1234 step identifier into $mydir/runtreex.use-this-treex-step"

STEP=$(cat $mydir/runtreex.use-this-treex-step)
[ -z "$STEP" ] && die "No treex given in $mydir/runtreex.use-this-treex-step"
[ -d "$mydir/../$STEP" ] || die "$STEP is not in $mydir/.."

TREEX=$mydir/../$STEP/treex

[ -e $TREEX.bashsource ] || die "$TREEX.bashsource not found"
source $TREEX.bashsource

treex -e WARN "$@"

exit $?
