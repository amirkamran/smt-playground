#!/bin/bash
# emits a parallel corpus for post-editing of tectomt
# emits it to stdout, so make sure to catch it

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

find /net/cluster/TMP/czeng_translated_by_tectomt/ -type f -name '*streex' \
| grep -v '[de]test' \
| gzip -c > infilelist.gz


qruncmd --jobs=20 --join " \
  source /net/tmp/bojar/wmt12-bojar/playground/s.treex.0274e2d1.20120223-0027/treex.bashsource ; \
  treex Read::Treex from=@- \
    Write::Factored outcols=csm:csmtectomt \
    flags=escape_space:join_spaced_numbers \
  " infilelist.gz

