# TS?=$(shell date '+%Y%m%d-%H%M')

SHELL=/bin/bash

all:
	# This Makefile just captures some further tasks you'd do in the
	# playground, but most of them are now facilitated by eman

.PHONY: reindex
reindex:
	# reindexing both eman and corpman
	eman reindex
	./corpman reindex

.PHONY: bl
bl:
	# recollect, redraw and show the file nicebleu.
	# Use 'vimremake nicebleu' if you are just tuning the visualization
	# rules but not collecting any new results.
	make -B nicebleu
	vim nicebleu

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

dlmloss:
	eman retag || echo "Ignoring errors"
	eman collect || echo "Ignoring errors"
	cat eman.results \
	| colgrep 3 --inv --re='^TAG' \
	| list2tab 1,2,5 3 4 - \
	| dett | sed 's/		/	-	/g' \
	| dett | sed 's/		/	-	/g' \
	| dett | sed 's/	$$/	-/g' \
	| tee clip.recut \
	| recut 1,5-,2,4,3 \
	| numsort testLOSS \
	| solve_first --skip=1 '^[\S]+\t[0-9.]' \
	| tt --utf8 \
	> $@

	

bleu:
	eman retag || echo "Ignoring errors"
	eman collect || echo "Ignoring errors"
	cat eman.results \
	| colgrep 3 --inv --re='^TAG' \
	| numsort a3 \
	| list2tab 1,2,5 3 4 \
	| recut 1,4-,2,3 \
	| numsort nBLEU \
	| sed '1s/^/Step/' \
	| sed 's/^s.\(2step\|mert\|eval\|evaluator\|combmert\)\.//' \
	| tt --utf8 \
	> $@

nicebleu: bleu
	eman tabulate || echo "Ignoring errors"
	cp eman.niceresults $@

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
	find -maxdepth 3 -ctime +$(AGE) -name 'run*.features.dat' -exec rm {} \;
	find -maxdepth 3 -ctime +$(AGE) -name 'run*.features.dat.gz' -exec rm {} \;
	find -maxdepth 3 -ctime +$(AGE) -name 'run*.scores.dat' -exec rm {} \;
	find -maxdepth 3 -ctime +$(AGE) -name 'run*.scores.dat.gz' -exec rm {} \;
	#find -maxdepth 3 -ctime +$(AGE) -name 'run*.best*.out.gz' -exec rm {} \;
	#rm -rf s.mert.*/mert-tuning/filtered
	#find -ctime +$(AGE) -name filtered-for-eval-std -exec rm -rf {} \; || true
	sleep 1800
	find -maxdepth 2 -ctime +$(AGE) -name 'alignment.custom' -exec rm {} \;
	find -maxdepth 2 -ctime +$(AGE) -name 'alignment.*.src' -exec rm {} \;
	find -maxdepth 2 -ctime +$(AGE) -name 'alignment.*.tgt' -exec rm {} \;
	# Other hot candidates to remove:
	# s.tm.*/model/phrase-table*unfiltered*

FREQAUG?=csNmT1+stc
freqlist.%:
	# vyrobi preqlist daneho korpusu, napr.
	#  FREQAUG=enNm+lc make freqlist.czeng10
	mkdir -p freqlists
	eval $$(./corpman --cmd $*/$(FREQAUG)) \
	| tr ' ' '\n' \
	| see \
	| gzip > freqlists/$*.$(FREQAUG).gz
