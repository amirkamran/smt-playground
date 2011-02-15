# TS?=$(shell date '+%Y%m%d-%H%M')

SHELL=/bin/bash

all:
	# This Makefile just captures some further tasks you'd do in the
	# playground, but most of them are now facilitated by ../scripts/eman

mertdetails:
	head -n -0 exp.mert.S*/log \
	| picklog \
	    '==>' pick '==> (.*) <==' \
	    let:START '^== Started:\s*([-0-9]+)' \
	    watch:ITERS '^\(([0-9]+)\) BEST at' \
	    'Tuned BLEU:' print:ITERS \
	    pick 'BLEU = ([^ ]+) ' \
	    'Default BLEU:' pick 'BLEU = ([^ ]+) ' \
	    print:START pick '^== Ended:\s*([-0-9]+)' \
	> $@

bleu:
	./collect_bleu.pl \
	| grep -v 'Processing [0-9]* sentences\|Evaluating candidate translations' \
	| grep -v '^$$' \
	| sed 's/BLEU.run\([0-9]*\)	/BLEU.run	\1:/' \
	| grp --keys=1,2 --items=COLLECT3 \
	| numsort a1 \
	| list2tab 1 2 3 '?' \
	| headline --prepend 'Mert or Eval' \
	| transpose | numsort a1 | transpose \
	| tt --utf8 \
	> $@.`./sitename`
	cat $@.* \
	| recut 1,4,5,6,8,7,3 \
	| numsort --skip=1 n1 \
	| tt --utf8 \
	> $@

nicebleu: bleu
	cat $< \
	| cut -f 1,3- \
	| dett \
	| ./summarizer.pl \
	| tt --utf \
	> $@

modelstat:
	make lsmodel | grep -v '^make' > $@.modeltmp
	cat $@.modeltmp | ./loginfo.sh - | prefix --tab prep \
	| paste $@.modeltmp - > $@.modeltmp2
	make lsmert | grep -v '^make' > $@.merttmp
	rm -f $@.merttmp2
	for e in `cat $@.merttmp`; do \
	  if [ -e $$e/info.modelexp ]; then \
	    cat $$e/info.modelexp >> $@.merttmp2; \
	  else \
	    echo '????' >> $@.merttmp2; \
	  fi ; \
	done
	cat $@.merttmp | ./loginfo.sh - | prefix --tab mert \
	| paste $@.merttmp2 - > $@.merttmp3
	( du -hs exp.model.[^0-9]* ; du -hs exp.modelclone.[^0-9]* ) \
	| grep -v '^0' \
	| tabrecalc "COL2\tsize\tCOL1" \
	> $@.sizetmp
	cat $@.modeltmp2 $@.merttmp3 $@.sizetmp \
	| grp --keys=1,2 --items=COLLECT3 \
	| list2tab 1 2 3 \
	| tt \
	> $@
	rm -f modelstat.modeltmp* modelstat.merttmp* modelstat.sizetmp*
	

all.oficbleu:
	for d in `make lsmert | grep exp.mert`; do \
	  if [ -e $$d/BLEU.opt ] && [ ! -e $$d/BLEU.opt.ofic ]; then \
	    echo qsubmake $$d/BLEU.opt.ofic ; \
	  fi \
	done

%/BLEU.opt.ofic: %/BLEU.opt
	./tools/wrapmteval.pl $*/evaluation.in $*/evaluation.ref.0 $*/evaluation.opt.out > $*/evaluation.mteval.result
	pickre --re='BLEU score = ([0-9.]+)' --pick < $*/evaluation.mteval.result \
	| cut -f 1 \
	> $@

	
exp.lm.%.binarize:
	# this should go into an eman seed or depend on BINARIES, not IRSTLM
	[[ -x $(IRSTLMDIR)/compile-lm ]]
	cd exp.lm.$* \
	&& if ! [ -e corpus.blm ]; then \
	     export TMP=/mnt/h/tmp; \
	     $(IRSTLMDIR)/compile-lm corpus.lm corpus.blm || exit 1; \
	   fi

AGE?=3
clean:
	find -ctime +$(AGE) -name 'run*.feats.opt.gz' -exec rm {} \;
	find -ctime +$(AGE) -name 'run*.feats' -exec rm {} \;
	find -ctime +$(AGE) -name 'run*.best*.out.gz' -exec rm {} \;
	find -ctime +$(AGE) -name filtered-for-eval-std -exec rm -rf {} \; || true
	find -maxdepth 2 -ctime +$(AGE) -name 'alignment.?.src' -exec rm {} \;
	find -maxdepth 2 -ctime +$(AGE) -name 'alignment.?.tgt' -exec rm {} \;
