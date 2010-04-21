#!/bin/bash

ws=../$(cat ../workspace)

model=$(cat info.modelexp)
tm=$(cat ../$model/deps | grep '\.tm\.')

factor=0

traintgt=../$tm/corpus/corpus.tgt.gz
trainsrc=../$tm/corpus/corpus.src.gz

oov=$ws/moses/scripts/analysis/oov.pl
echo "Using $oov"

testtgt=oov.evaluation.ref
cat evaluation.ref.0 | reduce_factors.pl 0 > $testtgt
testsrc=oov.evaluation.src
cat evaluation.in | reduce_factors.pl 0 > $testsrc

for n in 1 2 3 4; do \
  zcat $traintgt | reduce_factors.pl 0 \
  | eval $oov $testtgt --n=$n \
  | prefix --tab TGTcorp
  zcat $traintgt | reduce_factors.pl 0 \
  | eval $oov $testtgt --n=$n --src=$testsrc \
  | prefix --tab TGTcorp-source
  zcat $trainsrc | reduce_factors.pl 0 \
  | eval $oov $testsrc --n=$n \
  | prefix --tab SRCcorp
  for ttable in ttable-file*.gz; do
    zcat $ttable \
    | sed 's/ ||| /	/g' \
    | cut -f 2 \
    | reduce_factors.pl 0 \
    | eval $oov $testtgt --n=$n \
    | prefix --tab TGTttable
    zcat $ttable \
    | sed 's/ ||| /	/g' \
    | cut -f 2 \
    | reduce_factors.pl 0 \
    | eval $oov $testtgt --n=$n --src=$testsrc \
    | prefix --tab TGTttable-source
    zcat $ttable \
    | sed 's/ ||| /	/g' \
    | cut -f 1 \
    | reduce_factors.pl 0 \
    | eval $oov $testsrc --n=$n \
    | prefix --tab SRCttable
  done
done
