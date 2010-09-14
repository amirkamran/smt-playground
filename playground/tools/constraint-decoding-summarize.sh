#!/bin/bash
# summarizes all constr*logs

lcat constr-* \
| grep 'BEST TRANSLATION' \
| cut -d' ' -f1 \
| grp --keys=1,2 --items=ALL \
| pickre --re='(dl[0-9]+)' \
| pickre --re='(ttl[0-9]+)' \
> constr.data

cat constr.data \
| list2tab 3 4 5 \
| tabrecalc "COL1\tEVAL COL2+COL3 LAVE \tEVAL COL2/(COL2+COL3)*100 LAVE" \
    --skip=1 \
| pickre --re='(dl[0-9]+)' \
| pickre --re='(ttl[0-9]+)' \
> constr.perc

echo Sentences processed > constr
cat constr.perc \
| list2tab 1 2 4 \
| round 1 | tt \
>> constr

echo >> constr; echo >> constr

echo Reachable >> constr
cat constr.perc \
| list2tab 1 2 5 \
| sed 's/^ttl//; 1s/^/ttl/' \
| round 1 | tt \
| numsort --skip=1 1 \
| transpose | numsort --skip=1 d1 | transpose \
>> constr
