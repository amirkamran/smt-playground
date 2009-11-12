SHELL = /bin/bash

QSUB = /home/bojar/tools/shell/qsubmit
STATMT ?= ../..

# Use this just for debugging.
SCRIPTS_ROOTDIR = /home/bojar/diplomka/granty/euromatrix/moses_wmt09/workspace.20081208-2049/bin/scripts-20081208-2056

REDUCECOMBINE=$(SCRIPTS_ROOTDIR)/training/reduce_combine.pl

# We assume that ../ is the moses_playground directory that contains
# a correctly compiled workspace
WORKSPACE?=../$(shell cat ../workspace)

combine.%.gz:
	[ -x $(REDUCECOMBINE) ]
	while [ -e running.$*.gz ]; do \
	  echo "Waiting for "`cat running.$*.gz`" to finish!"; \
	  sleep 60; \
	done
	echo `hostname`" $$$$" > running.$*.gz
	set -o pipefail ; \
	eval `makearg --delim='\.' $* basename factors ` ;\
	  namedfactors=`echo $$factors | tr + '\n' | grep -v '^[0-9][0-9]*$$'`; \
	  spacedfactors=`echo $$factors | tr + ' '`; \
	  echo SPECIALIZING $$basename FOR FACTORS: $$spacedfactors; \
	  for f in $$namedfactors; do \
	    echo Making: factors/$$basename.$$f.gz; \
	    make factors/$$basename.$$f.gz || exit 1; \
	  done; \
	  echo Making combined corpus: $*.gz; \
	  $(REDUCECOMBINE) $$basename.gz $$spacedfactors \
	  | gzip -c > $*.gz
	date > $@
	rm running.$*.gz

factors/%.lc.gz:
	# anything lowercased
	[ -x $(REDUCECOMBINE) ]
	zcat $*.gz \
	| $(REDUCECOMBINE) - 0 \
	| $(STATMT)/scripts/lowercase.pl \
	| gzip -c > $@

CSSIMPLIFY=./cs_simplify_tag.pl

factors/%.pos.gz:
	# Czech part-of-speech
	[ -x $(CSSIMPLIFY) ]
	zcat $*.gz \
	| $(CSSIMPLIFY) --form=0 --lemma=1 --tag=2 \
	    --tweak=pos \
	| gzip -c > $@
factors/%.cng.gz:
	# Czech part-of-speech
	[ -x $(CSSIMPLIFY) ]
	zcat $*.gz \
	| $(CSSIMPLIFY) --form=0 --lemma=1 --tag=2 \
	    --tweak=cng \
	| gzip -c > $@
factors/%.cng03.gz:
	# Czech part-of-speech
	[ -x $(CSSIMPLIFY) ]
	zcat $*.gz \
	| $(CSSIMPLIFY) --form=0 --lemma=1 --tag=2 \
	    --tweak=cng03 \
	| gzip -c > $@
factors/%.cng03.gz:
	# Czech part-of-speech
	[ -x $(CSSIMPLIFY) ]
	zcat $*.gz \
	| $(CSSIMPLIFY) --form=0 --lemma=1 --tag=2 \
	    --tweak=cng03 \
	| gzip -c > $@
factors/%.ensimp1valem.gz:
	# English simplified valem, just change arg0-of-VERB to
	# arg0-of-VERBLEMMA (guessed)
	# In fact, this will never work, there's too much ambiguity in the
	# sentences.
	# I'm regenerating eaca corpora instead..., use numbered factor 6
factors/%.ensimp2valem.gz:
	# English simplified valem, just change arg0-of-VERB to arg0
	zcat $*.gz \
	| ./ensimpvalem.pl --valem=5 \
	| gzip -c > $@


# Creating standard devsets, eg.:
# wmt08csdev.gz wmt08entest.gz wmt08cstest.gz
wmt08cs%.gz: /home/bojar/diplomka/granty/euromatrix/tmt_czeng/devel/applications/czeng_analysis/fl.wmt08.nc-%2007.eaca.gz
	zcat $< \
	| cut -f2 \
	| gzip > $@
wmt08en%.gz: /home/bojar/diplomka/granty/euromatrix/tmt_czeng/devel/applications/czeng_analysis/fl.wmt08.nc-%2007.eaca.gz
	zcat $< \
	| cut -f1 \
	| gzip > $@
wmt08csdevtest.gz: /home/bojar/diplomka/granty/euromatrix/tmt_czeng/devel/applications/czeng_analysis/fl.wmt08.nc-devtest2007.cz-en.eaca.gz
	zcat $< \
	| cut -f2 \
	| gzip > $@
wmt08endevtest.gz: /home/bojar/diplomka/granty/euromatrix/tmt_czeng/devel/applications/czeng_analysis/fl.wmt08.nc-devtest2007.cz-en.eaca.gz
	zcat $< \
	| cut -f1 \
	| gzip > $@

# official testsets
wmt08enofictestnc.gz: /home/bojar/diplomka/granty/euromatrix/treedecode/src/prepare_corpora/zab/fl.wmt08.nc-test2008-src.eaca.gz
	zcat $< \
	| cut -f1 \
	| gzip > $@
wmt08csofictestnc.gz: /home/bojar/diplomka/granty/euromatrix/treedecode/src/prepare_corpora/zab/fl.wmt08.nc-test2008-src.eaca.gz
	zcat $< \
	| cut -f2 \
	| gzip > $@
wmt08enofictestnews.gz: /home/bojar/diplomka/granty/euromatrix/treedecode/src/prepare_corpora/zab/fl.wmt08.newstest2008-src.eaca.gz
	zcat $< \
	| cut -f1 \
	| gzip > $@
wmt08csofictestnews.gz: /home/bojar/diplomka/granty/euromatrix/treedecode/src/prepare_corpora/zab/fl.wmt08.newstest2008-src.eaca.gz
	zcat $< \
	| cut -f2 \
	| gzip > $@

# LREC 2008 experiments
LREC_ALL=D DP DC DCP DCX DCPX C P CX CPX
lrec-all: $(LREC_ALL:%=lrec%cs.gz) $(LREC_ALL:%=lrec%en.gz)
lrec%cs.gz: lrec2008-czeng-corpora/corp-%.lcbitxt.gz
	zcat $< \
	| cut -f 2 \
	| sed 's/  */ /g' | sed 's/^ //' | sed 's/ $$//' \
	| gzip > $@
lrec%en.gz: lrec2008-czeng-corpora/corp-%.lcbitxt.gz
	zcat $< \
	| cut -f 1 \
	| sed 's/  */ /g' | sed 's/^ //' | sed 's/ $$//' \
	| gzip > $@

# Lepsi johancin tagger, pomuze? Nepomohl...
johczengrcs.gz:
	zcat \
	  /home/bojar/diplomka/granty/euromatrix/johanko_vojed/vojeto_nove/johczengr.joined.gz \
	| cut -f 2 \
	| gzip -c > $@
johczenguics.gz:
	zcat \
	  /home/bojar/diplomka/granty/euromatrix/johanko_vojed/vojeto_nove/johczengui.joined.gz \
	| cut -f 2 \
	| gzip -c > $@

johczengren.gz:
	zcat \
	  /home/bojar/diplomka/granty/euromatrix/johanko_vojed/vojeto_nove/johczengr.joined.gz \
	| cut -f 1 \
	| gzip -c > $@
johczenguien.gz:
	zcat \
	  /home/bojar/diplomka/granty/euromatrix/johanko_vojed/vojeto_nove/johczengui.joined.gz \
	| cut -f 1 \
	| gzip -c > $@

# mstczeng with valems
mstczengeacacs.gz:
	zcat ../corpora/mstczeng/fl.ok.eaca.1-1.gdf.gz \
	| cut -f 3 \
	| gzip -c > $@
mstczengeacaen.gz:
	zcat ../corpora/mstczeng/fl.ok.eaca.1-1.gdf.gz \
	| cut -f 2 \
	| gzip -c > $@

# restricted to project syndicate
mstpseacacs.gz:
	zcat ../corpora/mstczeng/fl.ok.eaca.1-1.gdf.gz \
	| grep '^\./project_syndicate/' \
	| cut -f 3 \
	| gzip -c > $@
mstpseacaen.gz:
	zcat ../corpora/mstczeng/fl.ok.eaca.1-1.gdf.gz \
	| grep '^\./project_syndicate/' \
	| cut -f 2 \
	| gzip -c > $@

# devsets
mstwmt08eacaendev.gz: ../corpora/mstczeng/fl.wmt08.nc-dev2007.eaca.gz
	zcat $< \
	| cut -f 2 \
	| gzip -c > $@
mstwmt08eacacsdev.gz: ../corpora/mstczeng/fl.wmt08.nc-dev2007.eaca.gz
	zcat $< \
	| cut -f 3 \
	| gzip -c > $@

mstwmt08eacaenBIGdev.gz: ../corpora/mstczeng/fl.wmt08.nc-dev2007.eaca.gz ../corpora/mstczeng/fl.wmt08.nc-test2007.eaca.gz
	zcat $^ \
	| cut -f 2 \
	| gzip -c > $@
mstwmt08eacacsBIGdev.gz: ../corpora/mstczeng/fl.wmt08.nc-dev2007.eaca.gz ../corpora/mstczeng/fl.wmt08.nc-test2007.eaca.gz
	zcat $^ \
	| cut -f 3 \
	| gzip -c > $@

mstwmt08eacaendevtest.gz: ../corpora/mstczeng/fl.wmt08.nc-devtest2007.cz-en.eaca.gz
	zcat $< \
	| cut -f 2 \
	| gzip -c > $@
mstwmt08eacacsdevtest.gz: ../corpora/mstczeng/fl.wmt08.nc-devtest2007.cz-en.eaca.gz
	zcat $< \
	| cut -f 3 \
	| gzip -c > $@

mstczengetcacs.gz:
	zcat ../corpora/mstczeng/fl.ok.etca.1-1.gdf.gz \
	| cut -f 3 \
	| gzip -c > $@
mstczengetcaen.gz:
	zcat ../corpora/mstczeng/fl.ok.etca.1-1.gdf.gz \
	| cut -f 2 \
	| gzip -c > $@

mstwmt08etcaendev.gz: ../corpora/mstczeng/fl.wmt08.nc-dev2007.etca.gz
	zcat $< \
	| cut -f 2 \
	| gzip -c > $@
mstwmt08etcacsdev.gz: ../corpora/mstczeng/fl.wmt08.nc-dev2007.etca.gz
	zcat $< \
	| cut -f 3 \
	| gzip -c > $@

mstwmt08etcaendevtest.gz: ../corpora/mstczeng/fl.wmt08.nc-devtest2007.cz-en.etca.gz
	zcat $< \
	| cut -f 2 \
	| gzip -c > $@
mstwmt08etcacsdevtest.gz: ../corpora/mstczeng/fl.wmt08.nc-devtest2007.cz-en.etca.gz
	zcat $< \
	| cut -f 3 \
	| gzip -c > $@



# Hindi corpora
hindi-corpora: emille20080820en.gz emille20080820hi.gz \
               emille20080820deven.gz emille20080820devhi.gz \
	       emille20080820testen.gz emille20080820testhi.gz

emille20080820en.gz: emille20080820.enhi.train.gdf.gz
	zcat $< \
	| cut -f 3 \
	| ./escape_pipe_lt_gt.pl \
	| gzip -c > $@

emille20080820hi.gz: emille20080820.enhi.train.gdf.gz
	zcat $< \
	| cut -f 4 \
	| ./escape_pipe_lt_gt.pl \
	| gzip -c > $@

emille20080820%en.gz: emille20080820.enhi.%.gz
	zcat $< \
	| cut -f 3 \
	| ./escape_pipe_lt_gt.pl \
	| gzip -c > $@

emille20080820%hi.gz: emille20080820.enhi.%.gz
	zcat $< \
	| cut -f 4 \
	| ./escape_pipe_lt_gt.pl \
	| gzip -c > $@

## Rules used by augment:

%.factors/lc.gz:
	# augment.pl asks us to create lowercase corp $(CORP) lang $(LANG)
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| $(STATMT)/scripts/lowercase.pl \
	| gzip -c > $@

%.factors/lcstem4.gz:
	# augment.pl asks us to create lowercase corp $(CORP) lang $(LANG)
	./augment.pl --dump $(CORP)/$(LANG)+lc \
	| ./stem_factor.pl --stem=4 \
	| gzip -c > $@

%.factors/devnorm3lcstem4.gz:
	# augment.pl asks us to create corp $(CORP) lang $(LANG): $@
	./augment.pl --dump $(CORP)/$(LANG)+lc \
	| ./devnormal3.pl \
	| ./stem_factor.pl --stem=4 \
	| $(STATMT)/scripts/lowercase.pl \
	| gzip -c > $@


MKCLS=/home/bojar/diplomka/granty/jhuws-mt-2006/experiments/binaries/mkcls
%.factors/wc50.gz:
	# augment.pl asks us to create 50 word classes $(CORP) lang $(LANG)
	# and also drop distinctions between numbers
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| ./devnormal2.pl \
	| perl -pne 'tr/0123456789/5555555555/' \
	> $@.tempin
	$(MKCLS) -c50 -n2 -p$@.tempin -V$@.tempout opt
	map $@.tempout --pattern='\S+' --default=bug < $@.tempin \
	| gzip > $@

%.factors/TESTwc50.gz:
	# augment.pl asks us to reuse 50 word classes $(CORP) lang $(LANG)
	traincorp=`echo $(CORP) | sed 's/\.dev//' | sed 's/\.test//'`; \
	./augment.pl $$traincorp/$(LANG)+wc50 \
	&& ./augment.pl --dump $(CORP)/$(LANG)+form \
	| ./devnormal2.pl \
	| perl -pne 'tr/0123456789/5555555555/' \
	> $@.tempin \
	&& map $$traincorp/$(LANG).factors/wc50.gz.tempout --quiet --pattern='\S+' --default=unk < $@.tempin \
	| gzip > $@

%.factors/wc10.gz:
	# augment.pl asks us to create 10 word classes $(CORP) lang $(LANG)
	# and also drop distinctions between numbers
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| ./devnormal2.pl \
	| perl -pne 'tr/0123456789/5555555555/' \
	> $@.tempin
	$(MKCLS) -c10 -n2 -p$@.tempin -V$@.tempout opt
	map $@.tempout --pattern='\S+' --default=bug < $@.tempin \
	| gzip > $@


%.factors/TESTwc10.gz:
	# augment.pl asks us to reuse 10 word classes $(CORP) lang $(LANG)
	traincorp=`echo $(CORP) | sed 's/\.dev//' | sed 's/\.test//'`; \
	./augment.pl $$traincorp/$(LANG)+wc10 \
	&& ./augment.pl --dump $(CORP)/$(LANG)+form \
	| ./devnormal2.pl \
	| perl -pne 'tr/0123456789/5555555555/' \
	> $@.tempin \
	&& map $$traincorp/$(LANG).factors/wc10.gz.tempout --quiet --pattern='\S+' --default=unk < $@.tempin \
	| gzip > $@

%.factors/devnormal2.gz:
	# augment.pl asks us to create devanagari normalized corp $(CORP) lang $(LANG)
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| ./devnormal2.pl \
	| gzip -c > $@

%.factors/devnormal3.gz:
	# augment.pl asks us to create devanagari normalized corp $(CORP) lang $(LANG)
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| ./devnormal3.pl \
	| gzip -c > $@

%.factors/devnormal.gz:
	# augment.pl asks us to create devanagari normalized corp $(CORP) lang $(LANG)
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| ./devnormal.pl \
	| gzip -c > $@

%.factors/dzstemK.gz:
	# augment.pl asks us to create dzstem corp $(CORP) lang $(LANG)
	if [ ! -e $(CORP)/hindomorK.out.gz ]; then \
	  ./augment.pl --dump $(CORP)/$(LANG)+form \
	  | /home/zeman/projekty/hindstina/hindomor.pl -s \
	  | sed 's/| /|-- /g' | sed 's/|$$/|--/' \
	  | gzip > $(CORP)/hindomorK.out.gz; \
	fi
	zcat $(CORP)/hindomorK.out.gz \
	| $(REDUCECOMBINE) - 0 \
	| gzip -c > $@
%.factors/dzsufK.gz:
	# augment.pl asks us to create dzstem corp $(CORP) lang $(LANG)
	if [ ! -e $(CORP)/hindomorK.out.gz ]; then \
	  ./augment.pl --dump $(CORP)/$(LANG)+form \
	  | /home/zeman/projekty/hindstina/hindomor.pl -s \
	  | sed 's/| /|-- /g' | sed 's/|$$/|--/' \
	  | gzip > $(CORP)/hindomorK.out.gz; \
	fi
	zcat $(CORP)/hindomorK.out.gz \
	| $(REDUCECOMBINE) - 1 \
	| gzip -c > $@

%.factors/dzstem.gz:
	# augment.pl asks us to create dzstem corp $(CORP) lang $(LANG)
	if [ ! -e $(CORP)/hindomor.out.gz ]; then \
	  ./augment.pl --dump $(CORP)/$(LANG)+form \
	  | /home/zeman/projekty/hindstina/hindomor.pl \
	  | sed 's/| /|-- /g' | sed 's/|$$/|--/' \
	  | gzip > $(CORP)/hindomor.out.gz; \
	fi
	zcat $(CORP)/hindomor.out.gz \
	| $(REDUCECOMBINE) - 0 \
	| gzip -c > $@
%.factors/dzsuf.gz:
	# augment.pl asks us to create dzstem corp $(CORP) lang $(LANG)
	if [ ! -e $(CORP)/hindomor.out.gz ]; then \
	  ./augment.pl --dump $(CORP)/$(LANG)+form \
	  | /home/zeman/projekty/hindstina/hindomor.pl \
	  | sed 's/| /|-- /g' | sed 's/|$$/|--/' \
	  | gzip > $(CORP)/hindomor.out.gz; \
	fi
	zcat $(CORP)/hindomor.out.gz \
	| $(REDUCECOMBINE) - 1 \
	| gzip -c > $@

# unsupervised truecasing
TRDCTOOLS=~/diplomka/granty/euromatrix/treedecode/trunk/prepare_corpora/

# truecasing factors
%.factors/tc.gz:
	# augment.pl asks us to create automatic truecasing for corp $(CORP) lang $(LANG)
	# Ensure we have $(REDUCECOMBINE)
	[ -x $(REDUCECOMBINE) ]
	# Collect truecasing dictionary
	set -o pipefail ; \
	dict=$(CORP).$(LANG).uppercased_tokens; \
	if [ ! -e $$dict ] ; then\
	  echo "Extracting uppercased forms for $(LANG) from $(CORP)" >&2; \
	  ./augment.pl --dump $(CORP)/$(LANG)+form \
	  | $(TRDCTOOLS)/lowercase_beginnings_of_sentences.pl \
	      0 --collect-names-file=$$dict \
	  || exit 1 ; \
	fi; \
	echo "Truecasing according to $$dict" >&2 ; \
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| $(REDUCECOMBINE) - 0 \
	| $(TRDCTOOLS)/lowercase_beginnings_of_sentences.pl \
	    0 \
	    --names-file=$$dict \
	| gzip -c > $@

TRDCTOOLS=~/diplomka/granty/euromatrix/treedecode/trunk/prepare_corpora/
# hardwired rule just to keep track how the lexicon was collected
.PRECIOUS: english_uppercased_tokens
english_uppercased_tokens:
	./augment.pl --dump czeng-all/en+form \
	| $(TRDCTOOLS)/lowercase_beginnings_of_sentences.pl \
	    0 --collect-names-file=$@

%.factors/entc.gz: english_uppercased_tokens
	# English truecased
	[ -x $(REDUCECOMBINE) ]
	./augment.pl --dump $(CORP)/$(LANG)+form \
	| $(REDUCECOMBINE) - 0 \
	| $(TRDCTOOLS)/lowercase_beginnings_of_sentences.pl \
	    0 \
	    --names-file=english_uppercased_tokens \
	| gzip -c > $@

%.factors/cstc.gz:
	# Czech truecased
	[ -x $(REDUCECOMBINE) ]
	./augment.pl --dump $(CORP)/$(LANG) \
	| $(TRDCTOOLS)/add_truecased_form.pl 0:1:0:1 \
	    --replace-form \
	    --no-info \
	| $(REDUCECOMBINE) - 0 \
	| gzip -c > $@

%.factors/reverse.gz:
	# Reverse the alignment
	[ -e $(CORP)/$(LANG).gz ]
	zcat $(CORP)/$(LANG).gz \
	| ./reverse_alignment.pl \
	| gzip -c > $@

## Alignment

export DIRSYM?=gdfa
align:
	# usage: CORP=tides SRCAUG=en+lcstem4 TGTAUG=hi+lc make align
	#   optional settings: DIRSYM=int NAME=outname
	# about to align corp $(CORP) srcaug $(SRCAUG) tgtaug $(TGTAUG)
	# using symmetrization $(DIRSYM)
	[ ! -z "$(CORP)" ]
	[ ! -z "$(SRCAUG)" ]
	[ ! -z "$(TGTAUG)" ]
	[ ! -z "$(DIRSYM)" ]
	[ ! -z "$$NAME" ] \
	  || export NAME=`echo $(SRCAUG)-$(TGTAUG)-$(DIRSYM) | tr '+' '-'` \
	&& mkdir -p $(CORP) \
	&& ./check_and_print_vars CORP SRCAUG TGTAUG NAME DIRSYM > $(CORP)/$$NAME.vars \
	&& $(QSUB) \
	  --jobname align.$(CORP).$$NAME \
	  '/home/bojar/diplomka/kos/align/gizawrapper.pl \
	  `./augment.pl $(CORP)/$(SRCAUG)` \
	  `./augment.pl $(CORP)/$(TGTAUG)` \
	  --lfactors=0 --rfactors=0 \
	  --tempdir /mnt/h/tmp \
	  --bindir=$(WORKSPACE)/bin \
	  --dirsym=$(DIRSYM) \
	  | cut -f2 \
	  | gzip > $(CORP)/'"$$NAME"'.gz' \
	&& echo "ali" > $(CORP)/$$NAME.info
