#!/bin/bash
# This will pass stdin to stdout via treex command of the given scenario.

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

mydir=$(dirname $(readlink -f "$0" ) )
[ -d "$mydir" ] || die "Failed to find ourselves, got: $mydir"

STEP=s.treex.ba0dc9c8.20120110-1456
TREEX=$mydir/../$STEP/treex

[ -e $TREEX.bashsource ] || die "$TREEX.bashsource not found"
source $TREEX.bashsource

treex -e WARN "$@"

exit $?
