# preparing various combinations of aligned corpora

all:
	# no default target.

ALL=books celex euconst eujournal gnome kacenka kde microsoft \
    navajo_user_translations pcedt-rd pcedt-wsj project_syndicate rd2 subtitles

# disjoint sections
# D ... in Domain
# C ... Community, Legal
# X ... Community, Illegal
# P ... Professional
# M ... Microsoft Glossaries

export SECTION_D=project_syndicate
export SECTION_C=navajo_user_translations gnome kde
export SECTION_X=subtitles
export SECTION_P=books celex euconst eujournal kacenka pcedt-rd pcedt-wsj rd2
export SECTION_M=microsoft

# usage: make corp-DCX.bitxt.gz
corp-%.lcbitxt.gz:
	rm -f $@
	for s in `echo $* | sed 's/\(.\)/\1 /g'`; do \
	  for f in $$(eval echo '$$SECTION'_$$s); do \
	    echo Using $$f; \
	    ziplines $$f-en.txt.gz $$f-cs.txt.gz \
	    | paste - - \
	    | tr -d '|' \
	    | lowercase.pl \
	    | grep '[^[:space:]].*	[^[:space:]]' \
	    | gzip -c >> $@; \
	  done; \
	done

corp-%.gdf.gz: corp-%.lcbitxt.gz
	~/diplomka/kos/align/gizawrapper.pl \
	  $< \
	  --lfactors=0 --rfactors=0 \
	  --bindir=/home/bojar/diplomka/granty/jhuws-mt-2006/experiments/binaries/ \
	  --tempdir /mnt/h/tmp/ --dirsym=gdf \
	| gzip -c > $@

# all
all-corps:
	for f in P C CX CPX D DP DC DCP DCX DCPX; do \
	  make corp-$$f.lcbitxt.gz; \
	  qsubmake corp-$$f.gdf.gz; \
	done

stats:
	( for f in D C P X; do \
	  cn=corp-$$f.lcbitxt.gz; \
	  zcat $$cn | wc -l | prefix --tab "$$f\tSentences" ; \
	  zcat $$cn | cut -f1 | wc -w | prefix --tab "$$f\tTokens (en)" ; \
	  zcat $$cn | cut -f2 | wc -w | prefix --tab "$$f\tTokens (cs)" ; \
	  zcat $$cn | cut -f1 | tr ' ' '\n' | sort -u | wc -l | prefix --tab "$$f\tVocabulary (en)" ; \
	  zcat $$cn | cut -f2 | tr ' ' '\n' | sort -u | wc -l | prefix --tab "$$f\tVocabulary (cs)" ; \
	done ) \
	> $@

INDOMAINTEST=/export/work/people/bojar/diplomka/granty/euromatrix/moses_wmt08/exp.mert.SRClrecDCen+0.TGTlrecDCcs+0.LM0-3-lrecDCcsLM0-3-lrecDcs.t0-0.or-bi-fe.r0-0wmt08encslc.20080327-1254/evaluation.in
OUTOFDOMAINTEST=/export/work/people/bojar/diplomka/granty/euromatrix/moses_wmt08/exp.eval.SRClrecDCXen+0.TGTlrecDCXcs+0.LM0-3-lrecDCXcs.t0-0.or-bi-fe.r0-0wmt08encslcwmt08encs-test-newslc.20080327-1609/evaluation.in
oovstats:
	rm -f $@
	for s in D C P CX CPX DC DP DCP DCX DCPX; do \
	  trainf=`readlink -f ../lrec"$$s"en.gz`; \
	  echo Statistics for $$s ; \
	  ./oov-stats.pl $$trainf \
	    $(INDOMAINTEST) \
	    $(OUTOFDOMAINTEST) \
	  | sed "s:$$trainf:Training:" \
	  | sed 's:$(INDOMAINTEST):Test domain-D:' \
	  | sed 's:$(OUTOFDOMAINTEST):Test out-of-domain-D:' \
	  | prefix --tab $$s >> $@; \
	done
