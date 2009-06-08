# rules to create training and evaluation corpora for WMT09

all: ../synwebwmt/cs.gz

# Corpora based on /net/data/tectomt-SYN-WEB/export.gz

BIGFILE=/net/data/tectomt-SYN-WEB/export.gz
../synwebwmt/cs.gz:
	mkdir -p `dirname $@`
	zcat $(BIGFILE) \
	| cut -f2 \
	| gzip -c \
	> $@
	g=$@; echo 'form|lemma|tag|ord|gov|afun' > $${g%.gz}.info
	g=$@; zwc -l $@ | cut -f1 > $${g%.gz}.lines

../synwmt/cs.gz:
	mkdir -p `dirname $@`
	zcat $(BIGFILE) \
	| sed -n '1,37421937p;46229697,$$p' \
	| cut -f2 \
	| gzip -c \
	> $@
	g=$@; echo 'form|lemma|tag|ord|gov|afun' > $${g%.gz}.info
	g=$@; zwc -l $@ | cut -f1 > $${g%.gz}.lines

../wmt/cs.gz:
	mkdir -p `dirname $@`
	zcat $(BIGFILE) \
	| skip 46229600 \
	| grep '^wmt' \
	| cut -f2 \
	| gzip -c \
	> $@
	g=$@; echo 'form|lemma|tag|ord|gov|afun' > $${g%.gz}.info
	g=$@; zwc -l $@ | cut -f1 > $${g%.gz}.lines

# Corpora based on CzEng

CZENG=/home/bojar/diplomka/granty/euromatrix/tmt_wmt09/devel/applications/czeng_analysis
czeng.gz:
	ziplines $(CZENG)/all-better-ali.export.gz \
	  $(CZENG)/all-no-skip.export.eaca.lem-lem.int+gdf.gz \
	| cut -c66- \
	| paste - - \
	| cut -f1-10,12- \
	| gzip -c > $@
	echo "filename ea et e-lexrf e-auxrf ca ct c-lexrf c-auxrf t-ali GIZA-a-int GIZA-a-gdf" > $@.colnames

czeng%.export: czeng%.gz
	mkdir -p ../czeng$*
	zcat $< \
	| cut -f 2 \
	| gzip -c > ../czeng$*/en.gz
	echo 'form|lemma|tag|ord|gov|valem|lemvalem' > ../czeng$*/en.info
	zcat $< \
	| cut -f 6 \
	| gzip -c > ../czeng$*/cs.gz
	echo 'form|lemma|tag|ord|gov|afun' > ../czeng$*/cs.info
	zcat $< \
	| cut -f 12 \
	| gzip -c > ../czeng$*/czengaligdf.gz
	echo 'ali' > ../czeng$*/czengaligdf.info

# various subcorpora selections
czeng-ps.gz: czeng.gz
	zcat $< \
	| grep '^project_syndicate' \
	| gzip -c > $@

czeng-sub.gz: czeng.gz
	zcat $< \
	| grep '^subtitles' \
	| gzip -c > $@

czeng-nosub.gz: czeng.gz
	zcat $< \
	| grep -v '^subtitles' \
	| gzip -c > $@

czeng-all.gz: czeng.gz
	ln -s $< $@

# wmt09 dev and test sets
wmt09-devsets-all:
	for bn in nc-dev2007 nc-devtest2007 nc-test2007 nc-test2008 news-dev2009 news-dev2009a news-dev2009b news-test2009; do \
	  zcat $(CZENG)/wmt09.$$bn.export.gz \
	  | cut -c75- \
	  | gzip -c > wmt09-$$bn.gz; \
	  make wmt09-$$bn.export; \
	done

wmt09-%.export: wmt09-%.gz
	mkdir -p ../wmt09-$*
	zcat $< \
	| cut -f 2 \
	| gzip -c > ../wmt09-$*/en.gz
	echo 'form|lemma|tag|ord|gov|valem|lemvalem' > ../wmt09-$*/en.info
	zcat $< \
	| cut -f 6 \
	| gzip -c > ../wmt09-$*/cs.gz
	echo 'form|lemma|tag|ord|gov|afun' > ../wmt09-$*/cs.info


# Filtering subtitles

czeng-czech-words.gz:
	../augment.pl --dump czeng-nosub/cs+lc \
	| tr ' ' '\n' \
	| see \
	| gzip -c \
	> $@


## Combining full corpora with tc factors
# e.g. make czeng-ps.tc.gz

%.tc.gz: %.gz
	zcat $< \
	| ../paste_factors.pl --col=1 ../$*/en.factors/entc.gz  \
	| ../paste_factors.pl --col=5 ../$*/cs.factors/cstc.gz \
	| gzip > $@
