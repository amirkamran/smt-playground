#!/bin/bash

for dl in 3 6 10 30 40; do
  for ttl in 1 5 10 20 50 100; do
    jn=constr-dl$dl-ttl$ttl
    echo "qsubmit --jobname $jn " \
      '"'"./moses -f filtered-for-eval-opt/moses.ini -i evaluation.in -search-algorithm 0 -constraint evaluation.ref.0 -dl $dl -max-trans-opt-per-coverage $ttl"'"'
  done
done

