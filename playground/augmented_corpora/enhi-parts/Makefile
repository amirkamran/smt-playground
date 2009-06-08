# obtaining sources

# various fixes common to all corpora, e.g. drop the BOM char
GENERAL_FIXES= perl -pne 's/\x{ef}\x{bb}\x{bf}//g; s/  +/ /g; s/\t +/\t/; s/ +\t/\t/; s/^ +//; s/ +$$//;'

sources: acl2005.enhi.gz eilmt.enhi.gz tides.enhi.gz wikiner.enhi.gz \
  tides.dev.enhi.gz tides.test.enhi.gz tides.test-shortsent.enhi.gz \
  eilmt.dev.enhi.gz eilmt.test.enhi.gz
	cat < /export/work/people/bojar/diplomka/umc/devel/collected-data/emille/hunaligned.new \
	| $(GENERAL_FIXES) \
	| gzip \
	> emille.hun.gz
	cat < /export/work/people/bojar/diplomka/umc/devel/collected-data/DanielPipes/hunaligned \
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


wikiner.enhi.gz:
	cp -u /export/work/people/bojar/diplomka/umc/devel/collected-data/hindi-named-entities-from-wikipedia/hindi-NE-from-wiki.txt.gz $@

# various selections from hunaligned corpora

%-11.enhi.gz: %.hun.gz
	zcat $< \
	| colgrep 1 --re='^1-1$$' \
	| gzip > $@


# various combinations
ALL=eilmt tides emille-11 danielpipes-11 agrocorp-11 wikiner acl2005
all.enhi.gz: $(ALL:%=%.enhi.gz)
	zcat $^ \
	| gzip -c > $@

allFIX.enhi.gz: $(ALL:%=%.enhi.gz)
	zcat $^ \
	| gzip -c > $@

allFIX2.enhi.gz: $(ALL:%=%.enhi.gz)
	zcat $^ \
	| gzip -c > $@

EITI=eilmt tides
eiti.enhi.gz: $(EITI:%=%.enhi.gz)
	zcat $^ \
	| gzip -c > $@

%.export: %.enhi.gz
	# releasing an en-hi corpus to augmented corpora
	rm -rf ../icon-$*
	mkdir ../icon-$*
	zcat $< | cut -f 1 | ../escape_pipe_lt_gt.pl \
	| gzip > ../icon-$*/en.gz
	echo form > ../icon-$*/en.info
	zcat $< | cut -f 2 | ../escape_pipe_lt_gt.pl \
	| gzip > ../icon-$*/hi.gz
	echo form > ../icon-$*/hi.info


# exporting parsed (and retokenized) English

# enP stands for en parsed
%.export-enP: %.enP.gz %.enhi.gz
	# making sure we've got the same number of lines with orig .enhi
	[ `zwc -l $< | cut -f1` == `zwc -l $*.enhi.gz | cut -f1` ]
	zcat $< \
	| cut -f 2 \
	| gzip > ../icon-$*/enP.gz
	echo 'form|lem|tag|ord|gov|valem|lemvalem' > ../icon-$*/enP.info

# enR stands for en parsed and reordered
%.export-enR: %.enR.gz %.enhi.gz
	# making sure we've got the same number of lines with orig .enhi
	[ `zwc -l $< | cut -f1` == `zwc -l $*.enhi.gz | cut -f1` ]
	zcat $< \
	| cut -f 2 \
	| gzip > ../icon-$*/enR.gz
	echo 'form|lem|tag|ord|gov|valem|lemvalem' > ../icon-$*/enR.info

# use for eilmt, eilmt.dev, eilmt.test
%.enP.gz:
	cp /a/merkur1/bojar/moses_wmt09/augmented_corpora/enhi-parts/tmt/devel/personal/bojar/english_like_hindi/$*.export.gz \
	  $@

# use for eilmt, eilmt.dev, eilmt.test
%.enR.gz:
	cp /a/merkur1/bojar/moses_wmt09/augmented_corpora/enhi-parts/tmt/devel/personal/bojar/english_like_hindi/$*-reord.export.gz \
	  $@
