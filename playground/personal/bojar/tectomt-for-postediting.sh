#!/bin/bash
# emits a parallel corpus for post-editing of tectomt
# emits it to stdout, so make sure to catch it

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

dataset="$1"
[ ! -z "$dataset" ] || die "usage: $0 czeng|newstest2010|..."

if [ "$dataset" == czeng ]; then
  find /net/cluster/TMP/czeng_translated_by_tectomt/ -type f -name '*treex.gz' \
  | grep -v '[de]test' \
  | gzip -c > infilelist.gz
  OUTCOLS=ATTRid:ATTRczeng/filter_score:csmtectomt:csm:ALIa-cstectomt-cs-monolingual
  HACKSELECTOR=tectomt
  COLTEST="| coltest '\$3 =~ /[[:alpha:]]/ && \$4 =~ /[[:alpha:]]/'"
else
  find /net/tmp/bojar/wmt12-bojar/playground/personal/bojar/wmt-translated-by-tectomt/$dataset \
    -type f -name '*treex.gz' \
  | gzip -c > infilelist.gz
  OUTCOLS=csmtst
  HACKSELECTOR=tst
  COLTEST=""
fi


# the eval is a hack to fix a tectomt bug where "0" got set to ""

qruncmd --submit-sleep-every=200 --submit-sleep=30 --prio=-400 --split-to-size=20 --jobs=30000 --join " \
  source /net/tmp/bojar/wmt12-bojar/playground/s.treex.0274e2d1.20120223-0027/treex.bashsource ; \
  treex Read::Treex from=@- \
    Util::Eval language=cs selectors=$HACKSELECTOR anode='if (\$anode->form eq q()) { \$anode->set_form(q(0)); \$anode->set_lemma(q(0)); } \$anode->set_tag(q(X@-------------)) if (!defined \$anode->tag || \$anode->tag eq q());' \
    Write::Factored outcols=$OUTCOLS \
    flags=escape_space:join_spaced_numbers \
  $COLTEST
  " infilelist.gz

