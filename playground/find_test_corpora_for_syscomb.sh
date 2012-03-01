#!/bin/bash
# given a combmert step, it will scan all HYPAUGS for s.translate, and for
# those, it will try to identify variants that translated the given test set

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

[ ! -z "$2" ] || die "usage: $0 combmertstep desired-testcorp"

combmertstep=$(eman guess "$1")
[ ! -z "$combmertstep" ] || die "Failed to find $1"
testcorp="$2"

hypaugs=$(eman get-var $combmertstep HYPAUGS)

for h in `echo $hypaugs | tr : ' '`; do
  echo "Source $h:"
  echo -n "  "
  transkey=$(echo $h | sed 's/^.*\(s\.translate\.[0-9a-f]*\.[-0-9]*\).*$/\1/')
  transstep=""
  [ -z "$transkey" ] || transstep=$(eman guess "$transkey")
  if [ "$transstep" == "" ]; then
    echo "no s.translate step found"
  else
    # get the mertstep
    mertstep=$(eman tb $transstep --ignore=corpus --ignore=mert --vars | pickre --re='MERTSTEP=(.*)' --pick --cut)
    echo "$mertstep"
    if [ "$mertstep" != "" ]; then
      eman sel t translate vre $mertstep vre $testcorp --stat | prefix "  FOR $testcorp USE:\t"
      echo "  or run:"
      echo "    TESTCORP=$testcorp eman clone $transstep"
    fi
  fi
done
