#!/bin/bash
SCR=$STATMT/scripts
SGMLPATH=/net/data/wmt2012/test
EXP=$1
SRC=$2
TGT=$3
if [ -z "$SRC" ] || [ -z "$TGT" ] ; then
  echo Usage: presubmit.sh '<step> <srclang> <tgtlang>'
  echo STEP=$EXP
  echo SRC=$SRC
  echo TGT=$TGT
  exit 1;
fi
SGMLSRC=$SGMLPATH/newstest2012-src.$SRC.sgm
if ! [ -f $SGMLSRC ] ; then
  echo $SGMLSRC not found
  exit 2;
fi
cd $EXP
pwd
$SCR/capitalize_sentences.pl < corpus.translation | $SCR/detokenizer.pl -l $TGT > sysout.detok.txt
$SCR/normalize-punctuation.pl $TGT < sysout.detok.txt > sysout.detok.normalized.txt
# The hack with setids below is needed in 2012 because the organizers distributed flawed source files.
$SCR/wrap-xml.pl $TGT $SGMLSRC uk-dan-moses < sysout.detok.txt | sed 's/setid="newstest2011"/setid="newstest2012"/g' > sysout.$TGT.sgml
$SCR/wrap-xml.pl $TGT $SGMLSRC uk-dan-moses < sysout.detok.normalized.txt | sed 's/setid="newstest2011"/setid="newstest2012"/g' > sysout.$TGT.normalized.sgml
# matrix_submit_results.pl -usr zeman -psw XXX -src $SRC -tgt $TGT -notes $EXP sysout.$TGT.sgml
