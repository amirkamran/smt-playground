TS?=$(shell date '+%Y%m%d-%H%M')

PWD := $(shell pwd)
WS := $(shell cat workspace)
export SCRIPTS_ROOTDIR=$(shell cat $(WS)/scripts.rootdir 2>/dev/null)
export MOSESCMD=$(PWD)/$(WS)/moses/moses-cmd/src/moses
export SRILMDIR1=$(shell cat $(WS)/srilm.path 2>/dev/null)/bin
export SRILMDIR2=$(shell cat $(WS)/srilm.path 2>/dev/null)/bin/i686
export IRSTLMDIR=$(shell cat $(WS)/irstlm.bindir 2>/dev/null)
export RANDLMDIR=$(shell cat $(WS)/randlm.path 2>/dev/null)
SHELL=/bin/bash

all:
	# This Makefile just captures common tasks you'd do in the playground:
	#   make workspace  ... download, unpack and compile all external tools
	#   VAR1=val VAR2=val make exp.SEEDNAME.prepare
	#                       ... setup an experiment using seeds/exp.SEEDNAME
	#   make exp.EXPNAME.run  ... run the experiment
	#   make lsSEEDNAME   ... list all experiments, e.g. make lsmodel
	#
	#   Current dependencies of experiments:
	#     exp.lm  ->   exp.model     ->    exp.mert -> exp.eval
	#                   +--> exp.modelclone  --^
	#
	# Now checking if your workspace is ready: $(WS)
	# Make sure enter your workspace name (e.g. workspace.20081205-1342) to
	# the file 'workspace'
	[ -d "$(WS)" ]
	# Checking if moses executable exists:
	[ -x "$(MOSESCMD)" ]

# create a new experiment directory and use the seed script just to construct
# the TAG and set vars
exp.%.init:
	@seed="seeds/exp.$*" \
	&& [ -e "$$seed" ] || (echo "Seed $$seed not found" >&2; exit 1) \
	&& rundir=`mkdirhash exp.$*. .$(TS)` \
	&& [ -d "$$rundir" ] \
	&& echo "Preparing in directory $$rundir" >&2 \
	&& cp "$$seed" $$rundir/seed \
	&& set > $$rundir/env \
	&& cd $$rundir \
	&& ( if INIT_ONLY=yes /bin/bash seed >&2; then \
	       cd ../;\
	       if [ -e $$rundir/TAG ]; then \
		 tag=`cat $$rundir/TAG`; \
	         echo "Got tag: $$tag" >&2; \
	       fi; \
	       echo "Now continue with: make $$rundir.prep_inited" >&2; \
	       echo "$$rundir"; \
	     else \
	       echo "Failed to prepare the experiment." >&2; \
	       cd ..; rm -rf $$rundir ; \
	       exit 1 ;\
	     fi )

# prepare an inited experiment, using the vars as stored within the exp.
exp.%.prep_inited:
	rundir=exp.$* \
	&& cd $$rundir \
	&& ( if eval $$(cat VARS) RUN=no /bin/bash seed; then \
	       echo "Check the script $$rundir/command   or"; \
	       echo "  make $$rundir.run"; \
	       if [ "$(RUN)" == "yes" ]; then \
	         cd ../ \
	         && make $$rundir.run; \
	       fi; \
	     else \
	       echo "Failed to prepare the experiment."; \
	       exit 1 ;\
	     fi )

# prepare a fresh run of an experiment
exp.%.prepare:
	seed="seeds/exp.$*" \
	&& [ -e "$$seed" ] || (echo "Seed $$seed not found"; exit 1) \
	&& rundir=`mkdirhash exp.$*. .$(TS)` \
	&& [ -d "$$rundir" ] \
	&& echo "Preparing in directory $$rundir" \
	&& cp "$$seed" $$rundir/seed \
	&& set > $$rundir/env \
	&& cd $$rundir \
	&& ( if RUN=no /bin/bash seed; then \
	       cd ../;\
	       if [ -e $$rundir/TAG ]; then \
		 tag=`cat $$rundir/TAG`; \
	         echo "Got tag: $$tag" >&2; \
	       fi; \
	       echo "Check the script $$rundir/command   or"; \
	       echo "  make $$rundir.run"; \
	       if [ "$(RUN)" == "yes" ]; then \
	         make $$rundir.run; \
	       fi; \
	     else \
	       echo "Failed to prepare the experiment."; \
	       cd ..; rm -rf $$rundir ; \
	       exit 1 ;\
	     fi )

HOLDS?=
# format: HOLDS=-hold 12345 -hold 12346
# by default do not wait for any jobs

# start a prepared run of an experiment
exp.%.run:
	[ -e "exp.$*" ] || ( echo "The experiment has not been prepared yet?"; exit 1 )
	[ ! -e "exp.$*/log" ] || \
	  ( echo "The experiment has been already started. Will not rerun unless you move"; \
	  echo "the file exp.$*/log away."; \
	  exit 1 )
	cd exp.$* \
	&& if [ "$(QSUB)" == "no" ] \
	      || [ x`cat qsub-allowed 2>/dev/null` == "xno" ]; then \
	     (nohup /bin/bash command > log 2>&1 & ); \
	   else \
	     (qsubmit $(HOLDS) --jobname=log '/bin/bash command' 2>&1)>log; \
	   fi \
	&& echo "See exp.$*/log for progress."

exp.%.restart: exp.%
	# restarting an experiment
	eval `makearg --delim='\.' $* exptype ignore ` ;\
	  eval `cat $</VARS` make exp.$$exptype.prepare

# listing various types of experiments, eg. make lslm
ls%:
	@ls -dt exp.$** | grep -v 'exp.$*[^.]*.[-.0-9]*$$' | tac

# the most recent exp of a given type, eg. make lastlm
last%:
	@ls -dt exp.$** | grep -v 'exp.$*[^.]*.[-.0-9]*$$' | head -n1

# redo the last model of a given type:
redo%:
	eval $$(cat $$(make -s last$*)/VARS) make exp.$*.prepare

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
	| list2tab 1 2 3 '?' \
	| headline --prepend 'Mert or Eval' \
	| tt --utf8 \
	> $@.`./sitename`
	cat $@.* \
	| recut 2,1,3- \
	| numsort --skip=1 n1 \
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

	

# create fresh workspace with all tools
JOBS?=4
.PHONY: workspace
workspace:
	## Making sure you accept sourceforge's SSL certificate.
	## Please say (p)ermanently if you are asked anything:
	svn cat https://irstlm.svn.sourceforge.net/svnroot/irstlm/README \
	  > /dev/null
	## Setting up workspace $@.$$(TS)
	ts=$(TS) \
	&& ws=$@.$$ts \
	&& mkdir -p $$ws \
	&& cd $$ws \
	&& mkdir bin \
	&& echo `pwd`/bin > bindir.path \
	&& cd .. \
	&& if make -j$(JOBS) $$ws.giza $$ws.srilm $$ws.irstlm $$ws.randlm ; then\
	     make $$ws.moses; \
	   else \
	     echo "Some prerequisites failed." ; \
	     echo "Needed: giza srilm randlm irstlm. These succeeded: "; \
	     ls $$ws.* | sed 's/$$ws\./  /'; \
	     exit 1; \
	   fi \
	&& echo "Succeeded. To use this workspace run the following command: " \
	&& echo "  echo $$ws > workspace"

workspace.%.giza: workspace.%
	ws=$< \
	&& cd $$ws \
	&& tar xzf ../../src/giza-pp-v1.0.3.tar.gz \
	&& cd giza-pp \
	&& cd GIZA++-v2 && make && make snt2cooc.out && cd ../ \
	&& cd mkcls-v2 && make && cd ../ \
	&& cd ../ \
	&& mkdir -p bin \
	&& ln -s ../giza-pp/GIZA++-v2/GIZA++ ../giza-pp/GIZA++-v2/snt2cooc.out \
	      ../giza-pp/mkcls-v2/mkcls bin/
	date > $@ # confirm our success

workspace.%.randlm: workspace.%
	ws=$< \
	&& cd $$ws \
	&& tar xzf ../../src/randlm-v0.11.tar.gz \
	&& cd randlm \
	&& cd src && make all && cd .. \
	&& pwd > ../randlm.path \
	&& cd ../ \
	&& mkdir -p bin \
	&& ln -s ../randlm/bin/buildlm ../randlm/bin/querylm \
	      bin/
	date > $@ # confirm our success

SRILM_MACHTYPE=$(shell if [ `uname -m` == "x86_64" ]; then echo "i686-m64"; else echo "i686-gcc4"; fi)

workspace.%.srilm: workspace.%
	ws=$< \
	&& cd $$ws \
	&& echo "Extracting srilm" \
	&& mkdir srilm \
	&& cd srilm \
	&& tar xzf ../../../src/srilm.tgz \
	&& export SRILM=`pwd` \
	&& export NO_TCL=X \
	&& make -j4 MACHINE_TYPE=$(SRILM_MACHTYPE) World \
	&& echo "Making symlinks so that Moses will find srilm" \
	&& if [ -e lib/i686-m64 ] ; then ln -s i686-m64 lib/i686; fi \
	&& if [ -e lib/i686-gcc4 ] ; then ln -s i686-gcc4 lib/i686; fi \
	&& if [ -e bin/i686-m64 ] ; then ln -s i686-m64 bin/i686; fi \
	&& if [ -e bin/i686-gcc4 ] ; then ln -s i686-gcc4 bin/i686; fi \
	&& pwd > ../srilm.path
	date > $@ # confirm our success

# Use UFAL Moses repository by default:
MOSES_GIT_UPDATE_COMMAND?=pull
MOSES_GIT_CLONE_FROM?=clone /net/work/projects/moses-ufal-git-repo
# Alternatively use official moses SVN source:
# MOSES_GIT_UPDATE_COMMAND=svn rebase
#MOSES_START_REVISION?=0
#MOSES_GIT_CLONE_FROM?=svn clone -r $(MOSES_START_REVISION):HEAD \
#               https://mosesdecoder.svn.sourceforge.net/svnroot/mosesdecoder/trunk

workspace.%.moses: workspace.%
	ws=$< \
	&& cd $$ws \
	&& if [ -e moses ]; then \
	     echo "Just updating moses..." ; \
	     cd moses && git $(MOSES_GIT_UPDATE_COMMAND) && cd .. ; \
	   else \
	     git $(MOSES_GIT_CLONE_FROM) moses ; \
	   fi\
	&& cd moses \
	&& ./regenerate-makefiles.sh \
	&& ./configure --with-irstlm=`cat ../irstlm.path` \
	               --with-srilm=`cat ../srilm.path` \
	               --with-randlm=`cat ../randlm.path` \
	&& make -j 4 \
	&& rm -f ../bin/moses \
	&& ln -s ../moses/moses-cmd/src/moses ../bin/ \
	&& cd scripts \
	  && TARGETDIR=`cat ../../bindir.path` \
	     BINDIR=`cat ../../bindir.path` \
	       make release \
	  && eval 'ls -dt '`cat ../../bindir.path`'/scripts-* | head -n1' \
	      > ../../scripts.rootdir \
	&& cd .. \
	&& ln -s ../moses/scripts/training/symal/symal ../bin/
	date > $@ # confirm our success

workspace.%.irstlm: workspace.%
	# workaround for a irstlm makefile error 
	if [ 'Darwin' = `uname` ]; \
	    then export OSTYPE='darwin'; \
	fi \
	&& ws=$< \
	&& cd $$ws \
	&& svn --non-interactive \
	    co https://irstlm.svn.sourceforge.net/svnroot/irstlm irstlm \
	&& cd irstlm \
	&& ./regenerate-makefiles.sh \
	&& ./configure --prefix=`pwd`\
	&& make -j 4 \
	&& make install \
	&& cd lib && ln -s x86_64?* x86_64 ; ln -s i386?* i386 ; ln -s x86_64?* i686 ; cd .. \
	&& cd bin && ln -s x86_64?* x86_64 ; ln -s i386?* i386 ; ln -s x86_64?* i686 ; cd .. \
	&& eval echo `pwd`/bin/`uname -m`/ \
	    > ../irstlm.bindir \
	&& echo `pwd` \
	    > ../irstlm.path \
	&& cd .. \
	# Checking if libirstlm was successfully created
	[ -e $</irstlm/lib/`uname -m`/libirstlm.a ]
	date > $@ # confirm our success

workspace.%.salm: workspace.%
	ws=$< \
	&& cd $$ws \
	&& wget http://projectile.sv.cmu.edu/research/public/tools/salm/src/salm-src.tar.gz \
	&& tar xzf salm-src.tar.gz \
	&& mv SALM salm-src \
	&& cd salm-src/Distribution/Linux \
	&& make allO64 || [ -x ../../Bin/Linux/Index/IndexSA.O64 ] \
	&& cd ../../../bin \
	&& ln -s ../salm-src/Bin/Linux/Index/IndexSA.O64 ./ \
	&& ln -s ../salm-src/Bin/Linux/Search/FrequencyOfNgrams.O64 ./ \
	&& cd .. \
	&& echo `pwd`/salm-src > salm.path
	date > $@ # confirm our success

workspace.%.tmt: workspace.%
	ws=$< \
	&& cd $$ws \
	&& mkdir tmt || exit 1 \
	&& cd tmt \
	&& svn co https://svn.ms.mff.cuni.cz/svn/tectomt_devel/trunk . \
	    || exit 1  \
	&& if [ -e /net/projects/tectomt_shared/ ]; then \
	     ln -s /net/projects/tectomt_shared/ share ; \
	   else \
	     wget http://ufal.mff.cuni.cz/~zabokrtsky/tectomt_shared.zip \
	      && unzip tectomt_shared.zip ; \
	   fi \
	&& ln -s /mnt/h/tmp ./tmp


exp.lm.%.binarize:
	[[ -x $(IRSTLMDIR)/compile-lm ]]
	cd exp.lm.$* \
	&& if ! [ -e corpus.blm ]; then \
	     export TMP=/mnt/h/tmp; \
	     $(IRSTLMDIR)/compile-lm corpus.lm corpus.blm || exit 1; \
	   fi

clean:
	find -name 'run*.feats.opt.gz' -exec rm {} \;
	find -name 'run*.feats' -exec rm {} \;
	find -name 'run*.best*.out.gz' -exec rm {} \;
	find -name filtered-for-eval-std -exec rm -rf {} \; || true
