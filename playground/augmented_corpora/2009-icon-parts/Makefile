# obtaining sources for 2009 ICON paper

SHELL=/bin/bash

# various fixes common to all corpora, e.g. drop the BOM char
GENERAL_FIXES= perl -pne 's/\x{ef}\x{bb}\x{bf}//g; s/  +/ /g; s/\t +/\t/; s/ +\t/\t/; s/^ +//; s/ +$$//;'

all:
	# make sources   ... will collect data from various places to this dir
	#                ... have a look at them
	# make export    ... will put them as corpora to $$EXPORTDIR
	#                    i.e. $(EXPORTDIR)

sources: acl2005.enhi.gz eilmt.enhi.gz tides.enhi.gz \
  wikiner2008.enhi.gz wikiner2009.enhi.gz \
  tides.dev.enhi.gz tides.test.enhi.gz \
  eilmt.dev.enhi.gz eilmt.test.enhi.gz
	zcat < /home/bojar/diplomka/umc/devel/collected-data/emille/emille-refined-by-gaurav.all-at-once.hun.gz \
	| $(GENERAL_FIXES) \
	| gzip \
	> emille.hun.gz
	cat < /export/work/people/bojar/diplomka/umc/devel/collected-data/DanielPipes-enhi/hunaligned \
	| $(GENERAL_FIXES) \
	| gzip \
	> danielpipes.hun.gz
	cat < /export/work/people/bojar/diplomka/umc/devel/collected-data/hindi-agrocorpus/hunaligned \
	| $(GENERAL_FIXES) \
	| gzip \
	> agrocorp.hun.gz

acl2005.enhi.gz:
	paste /export/work/people/stranak/hindi/jine/English-Hindi.training/acl2005englishV1.txt /export/work/people/stranak/hindi/jine/English-Hindi.training/acl2005hindiV1.txt \
	| perl -npe 's/\r//g' \
	| $(GENERAL_FIXES) \
	| gzip \
	> $@

eilmt.enhi.gz:
	ziplines /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/eilmt_tourism.train.en.gz \
	  /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/eilmt_tourism.train.hi.gz \
	| paste - - \
	| $(GENERAL_FIXES) \
	| gzip \
	> $@

tides.enhi.gz:
	ziplines /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/tides_iiit.train.en.gz \
	  /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/tides_iiit.train.hi.gz \
	| paste - - \
	| $(GENERAL_FIXES) \
	| gzip \
	> $@

# use for: tides.dev.enhi.gz tides.test.enhi.gz tides.test-shortsent.enhi.gz
tides.%.enhi.gz:
	ziplines /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/tides_iiit.$*.en.gz \
	  /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/tides_iiit.$*.hi.gz \
	| paste - - \
	| $(GENERAL_FIXES) \
	| gzip \
	> $@

# use for: eilmt.dev.enhi.gz eilmt.test.enhi.gz
eilmt.%.enhi.gz:
	ziplines /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/eilmt_tourism.$*.en.gz \
	  /export/work/people/bojar/diplomka/umc/devel/collected-data/icon-shared-task-2009/eilmt_tourism.$*.hi.gz \
	| paste - - \
	| $(GENERAL_FIXES) \
	| gzip \
	> $@


wikiner2008.enhi.gz:
	cat /export/work/people/bojar/diplomka/umc/devel/collected-data/hindi-named-entities-from-wikipedia/hindi-NE-from-wiki.txt.gz \
	| $(GENERAL_FIXES) \
	| gzip \
	> $@

wikiner2009.enhi.gz:
	cat ../../../projects/enhi/data/NEs-hi-dev-ma-enwiki-20090520.txt \
	| $(GENERAL_FIXES) \
	| gzip \
	> $@

# various selections from hunaligned corpora

%-11.enhi.gz: %.hun.gz
	zcat $< \
	| colgrep 1 --re='^1-1$$' \
	| colgrep 3 --re='.' \
	| colgrep 4 --re='.' \
	| cut -f 3,4 \
	| gzip > $@


# exporting
ALL=eilmt tides emille-11 danielpipes-11 agrocorp-11 wikiner2008 wikiner2009 acl2005 tides.test tides.dev
export: $(ALL:%=%.export)


EXPORTDIR?=/net/projects/hindi/data/augmented_corpora

%.export: %.enhi.gz
	# releasing an en-hi corpus to augmented corpora
	if [ -e $(EXPORTDIR)/$* ]; then \
	  echo "Target directory $(EXPORTDIR)/$* exists, delete yourself." >&2 ;\
	  exit 1;
	fi
	mkdir $(EXPORTDIR)/$*
	zcat $< | cut -f 1 | $(EXPORTDIR)/escape_pipe_lt_gt.pl \
	| gzip > $(EXPORTDIR)/$*/en.gz
	echo form > $(EXPORTDIR)/$*/en.info
	zcat $< | cut -f 2 | $(EXPORTDIR)/escape_pipe_lt_gt.pl \
	| gzip > $(EXPORTDIR)/$*/hi.gz
	echo form > $(EXPORTDIR)/$*/hi.info


## exporting parsed (and retokenized) English
#
## enP stands for en parsed
#%.export-enP: %.enP.gz %.enhi.gz
#	# making sure we've got the same number of lines with orig .enhi
#	[ `zwc -l $< | cut -f1` == `zwc -l $*.enhi.gz | cut -f1` ]
#	zcat $< \
#	| cut -f 2 \
#	| gzip > $(EXPORTDIR)/icon-$*/enP.gz
#	echo 'form|lem|tag|ord|gov|valem|lemvalem' > $(EXPORTDIR)/icon-$*/enP.info
#
## enR stands for en parsed and reordered
#%.export-enR: %.enR.gz %.enhi.gz
#	# making sure we've got the same number of lines with orig .enhi
#	[ `zwc -l $< | cut -f1` == `zwc -l $*.enhi.gz | cut -f1` ]
#	zcat $< \
#	| cut -f 2 \
#	| gzip > $(EXPORTDIR)/icon-$*/enR.gz
#	echo 'form|lem|tag|ord|gov|valem|lemvalem' > $(EXPORTDIR)/icon-$*/enR.info
#
## use for eilmt, eilmt.dev, eilmt.test
#%.enP.gz:
#	cp /a/merkur1/bojar/moses_wmt09/augmented_corpora/enhi-parts/tmt/devel/personal/bojar/english_like_hindi/$*.export.gz \
#	  $@
#
## use for eilmt, eilmt.dev, eilmt.test
#%.enR.gz:
#	cp /a/merkur1/bojar/moses_wmt09/augmented_corpora/enhi-parts/tmt/devel/personal/bojar/english_like_hindi/$*-reord.export.gz \
#	  $@
