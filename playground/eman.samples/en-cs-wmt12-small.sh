#!/bin/bash

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

[ -d eman.seeds ] || die "This script expects to be run from your playground"

if [ -e tools/runtreex.use-this-treex-step ]; then
  echo "Reusing your registered treex:" \
    $(cat tools/runtreex.use-this-treex-step)
else
  treexstep=`eman init treex --print-created-step --start`
  [ -d "$treexstep" ] || die "Failed to create treex step"
  echo "Waiting till your treex step will be ready"
  eman wait $treexstep || die "Failed to make treex step"
  
  echo $treexstep > tools/runtreex.use-this-treex-step \
  || die "Echo failed to register treex for tools/runtreex.sh"
fi

echo "Preparing raw corpora"
for i in 0 1 2 3 4; do
  datastep=`eman clone --print-created-step --start < eman.samples/en-cs-wmt12-small.data$i`
  datasteps="$datasteps $datastep"
done
echo "Waiting till raw corpora are ready"
eman wait $datasteps || die "Some of the corpora were not created"

mertstep=`eman clone --print-created-step < eman.samples/en-cs-wmt12-small.mert`
echo "Your baseline mert for WMT12 should be here: $mertstep"
echo "Please run:"
echo "  eman start $mertstep"
