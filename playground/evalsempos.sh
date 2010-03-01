#!/bin/bash

function die() { echo "$@" | tee FAILED >&2; exit 1 ; }
set -o pipefail

[ ! -z "$1" ] || die "usage: $0 exp-identifier"

SRUNBLOCKS=/home/bojar/diplomka/granty/emplus/wmt10/playground/workspace.20091113-2336/tmt2/tools/srunblocks_streaming/srunblocks
QRUNCMD=/home/bojar/bin//qruncmd
JOBS=30

d=`./manager.pl --guess $1`
[ -d "$d" ] || die "Not an experiment: $d"

cd $d || die "Failed to chdir"

[ -x "$SRUNBLOCKS" ] || die "Can't run $SRUNBLOCKS"
[ -x "$QRUNCMD" ] || die "Can't run $QRUNCMD"

hypfile="evaluation.opt.txt"
[ -e $hypfile ] || die "Hypothesis $hypfile not found"

testcorp=`cat VARS | grep ^TESTCORP | cut -d= -f2`
[ -d ../augmented_corpora/$testcorp ] || die "Testcorp $testcorp not found"

tgtlan=csNa
refcorp=`../augmented_corpora/augment.pl $testcorp/$tgtlan+tlemma+sempos`

[ -e $refcorp ] || die "Failed to get t-layer of reference set"

[ x`wc -l < $hypfile` == x`zcat $refcorp | wc -l ` ] || die "Mismatched linecount: $hypfile vs $refcorp"

zcat $refcorp > evaluation.semposbleu.ref.0 \
  || die "Failed to make local copy of reference set"

refcorp=evaluation.semposbleu.ref.0

cat << KONEC > evaluation.opt.sempos.scen
SCzechW_to_SCzechM::Tokenize_joining_numbers
SCzechW_to_SCzechM::TagMorce
# SCzechM_to_SCzechN::Czech_named_ent_SVM_recognizer
# SCzechM_to_SCzechN::Geo_ne_recognizer
# SCzechM_to_SCzechN::Embed_instances
SCzechM_to_SCzechA::McD_parser_local TMT_PARAM_MCD_CZ_MODEL=pdt20_train_autTag_golden_latin2_pruned_0.02.model
# SCzechM_to_SCzechA::McD_parser_local TMT_PARAM_MCD_CZ_MODEL=pdt20_train_autTag_golden_latin2_pruned_0.10.model
SCzechM_to_SCzechA::Fix_atree_after_McD
SCzechM_to_SCzechA::Fix_is_member
SCzechA_to_SCzechT::Mark_auxiliary_nodes
SCzechA_to_SCzechT::Build_ttree
SCzechA_to_SCzechT::Fill_is_member
SCzechA_to_SCzechT::Rehang_unary_coord_conj
SCzechA_to_SCzechT::Assign_coap_functors
SCzechA_to_SCzechT::Fix_is_member
SCzechA_to_SCzechT::Distrib_coord_aux
SCzechA_to_SCzechT::Mark_clause_heads
SCzechA_to_SCzechT::Mark_relclause_heads
SCzechA_to_SCzechT::Mark_relclause_coref
SCzechA_to_SCzechT::Fix_tlemmas
SCzechA_to_SCzechT::Assign_nodetype
SCzechA_to_SCzechT::Assign_grammatemes
SCzechA_to_SCzechT::Detect_formeme
SCzechA_to_SCzechT::Add_PersPron
SCzechA_to_SCzechT::Mark_reflpron_coref
SCzechA_to_SCzechT::TBLa2t_phaseFd
Print::ForSemPOSBLEUMetric TMT_PARAM_PRINT_FOR_SEMPOS_BLEU_METRIC=m:form|t_lemma|gram/sempos TMT_PARAM_PRINT_FOR_SEMPOS_BLEU_METRIC_DESTINATION=factored_output
KONEC

if [ ! -e evaluation.opt.semposbleu ]; then
  $QRUNCMD --jobs=$JOBS --join \
    "$SRUNBLOCKS --errorlevel=FATAL evaluation.opt.sempos.scen \
      czech_source_sentence factored_output " \
    evaluation.opt.txt \
  > evaluation.opt.semposbleu
fi

echo Now use evaluation.opt.txt and evaluation.sempos.ref.0 to create SemPOS.opt
