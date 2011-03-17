# rules to create training and evaluation corpora for WMT11

# BUGS:
#   Empty line:
#   czeng09-te/cs.gz         101262
#   ...a to proto, ze ceska veta obsahuje jeden znak: 0
#   techdoc-b167886-08train-f012678-s13     Nil     0

SHELL=/bin/bash

all:
	# download and clean plaintexts of the devsets
	make dev.plaintext cleaned/ps.gz cleaned/europarl.gz cleaned/ecweb.gz \
	  cleaned/ecnews.gz cleaned/journal.gz
	./make_all_configs.pl < configs
	# Also manually run:
	#   make ../webcoll
	#   make ../syn200x
	# And once all plaintexts are ready, these are the analysis commands:
	#   make runall
	#   make joinedpara

PARACONSTRAIN=czeng09-ne czeng09-eu czeng09-fi czeng09-na czeng09-su czeng09-te czeng09-we ps europarl
PARAEXTRA=emea ted
PARACORP=wmt08 wmt09 wmt10 $(PARACONSTRAIN)
MONOCORP=monops monoeuroparl mononews07 mononews08 mononews09 mononews10 mononews11 webcoll syn200x
runall:
	@for c in $(PARACORP); do \
	  for l in csNm enNm csNmT1 enNmT1; do \
	    echo ../augment.pl $$c/$$l ; \
	  done ; \
	done
	@for c in $(MONOCORP); do \
	  for l in csNm csNmT1; do \
	    echo ../augment.pl $$c/$$l ; \
	  done ; \
	done

joinedpara:
	@for l in csNmT1 enNmT1; do \
	  echo ../augment.pl $$(echo $(PARACONSTRAIN) $(PARAEXTRA) | tr ' ' +)/$$l; \
	  echo ../augment.pl $$(echo $(PARACONSTRAIN) | tr ' ' +)/$$l ; \
	done

# Outdated
# justwmtdevs: plaintext.wmt10dev
# 	cd .. \
# 	&& for d in wmt102.test*; do zcat $$d/cs_txt.gz | wc -l > $$d/LINECOUNT; done \
# 	&& for d in wmt102.test*; do echo untok > $$d/cs_txt.info; done \
# 	&& for d in wmt102.test*; do echo untok > $$d/en_txt.info; done

# Some big corpora are created using custom rules

../webcoll:
	# create plaintext of webcoll monolingual czech texts
	mkdir $@
	set -o pipefail ; \
	for f in /net/data/webcoll/tok/*.tar.gz ; do \
	  tar xzfO $$f; \
	done \
	| qruncmd --jobname=webcoll --jobs=$(JOBS) \
	    'iu | csts_stream_to_plaintext_stream.pl | remove_blank_lines | tr -d "\000-\010\013\014\016-\037" | ./fix_whitespace.pl ' \
	| gzip -c > $@/cs_txt.gz
	echo untokenized > $@/cs_txt.info
	zcat $@/cs_txt.gz | wc -l > $@/LINECOUNT

../syn200x:
	 create plaintext of syn2000, 2005 and 2006pub monolingual czech texts
	mkdir $@
	# first the 2006, which is in utf-8
	ls /home/bojar/NEZALOHOVANE/SYN2006pub/hajic/*.gz \
	| qruncmd --jobname=syn2006 --jobs=$(JOBS) \
	    'autocat --filelist=- | csts_stream_to_plaintext_stream.pl | remove_blank_lines' \
	| gzip -c > $@/cs_unseg.gz
	# now the 200[05], in windows-1250
	ls /net/data/CNK-SYN/syn2000/in/*.gz \
	   /net/data/CNK-SYN/syn2005/in/*.gz \
	| qruncmd --jobname=syn2000_5 --jobs=$(JOBS) \
	    "autocat --filelist=- | iconv -f windows-1250 -t utf-8 | perl -pne 's/\r//g; s/&doc;/\n/g; s/$$/\n/g;' | remove_blank_lines" \
	| gzip -c >> $@/cs_unseg.gz
	# now segment
	qruncmd --jobname=synsegment --jobs=$(JOBS) \
	    '$(SRUNBLOCKS) SCzechW_to_SCzechM::TextSeg_tokenizer_and_segmenter --store-input-to=document czech_source_text czech_source_sentence --allow-many-output-bundles --errorlevel FATAL | ./fix_whitespace.pl ' \
	    $@/cs_unseg.gz \
	| gzip -c > $@/cs_txt.gz
	echo untokenized > $@/cs_txt.info
	zcat $@/cs_txt.gz | wc -l > $@/LINECOUNT

CZENG09PLAINTEXTSDIR=/net/data/czeng09-public-release/data-plaintext/

TMTROOT=/home/bojar/diplomka/granty/emplus/wmt11/playground/s.tectomt.37453b1c.20110201-1501/tectomt
SRUNBLOCKS=$(TMTROOT)/tools/srunblocks_streaming/srunblocks


JOBS?=40

# Generic analyzer

OUTCORPNAME?=czeng09-s00
ANOTLANG?=cs
OUTLANG?=$(ANOTLANG)
SCENTYPE?=a
FILENAMERE?=00
#FILENAMERE?=[0-79][0-9]
COLUMNRE?=.

LANGCOL-cs=3
LANGCOL-en=2
LANGNAME-cs=czech
LANGNAME-en=english
test:
	echo $(LANGCOL-$(ANOTLANG))
	echo $(LANGNAME-$(ANOTLANG))

SOURCES= \
  /home/bojar/diplomka/czeng/devel/completion/emea.filtered.undup.gz \
  /export/home/bojar/diplomka/umc/devel/collected-data/czechnews-aktualne.cz/hunalign.ctxclean.gz \
  /net/data/WMT11/training/* \
  /net/data/WMT11/training-monolingual/* \
  ./cleaned/* \
  ./dev.plaintext/* \
  /export/home/bojar/diplomka/umc/devel/collected-data/ted.com/plaintexts.txt.gz \
  $(CZENG09PLAINTEXTSDIR)/*.gz

cleaned/ps.gz:
	# removing misencoded lines
	mkdir -p cleaned
	ziplines --item-delim='\t' \
	  /net/data/WMT11/training/news-commentary-v6.cs-en.en.gz \
	  /net/data/WMT11/training/news-commentary-v6.cs-en.cs.gz \
	| grep -v 'Ã¡\|Ã©' \
	| ./fix_whitespace.pl \
	| grep -v '^ *	\|	 *$$' \
	| gzip -c \
	> $@

cleaned/europarl.gz:
	# removing Greek and nonparallel sentences
	mkdir -p cleaned
	ziplines --item-delim='\t' \
	  /net/data/WMT11/training/europarl-v6.cs-en.en.gz \
	  /net/data/WMT11/training/europarl-v6.cs-en.cs.gz \
	| grep -v '[αάβδεηιίκλμνόπρσςτυ][αάβδεηιίκλμνόπρσςτυ][αάβδεηιίκλμνόπρσςτυ][αάβδεηιίκλμνόπρσςτυ]' \
	| ./fix_whitespace.pl \
	| grep -v '^ *	\|	 *$$' \
	| gzip -c \
	> $@

cleaned/journal.gz:
	# selecting usable sentences of eujournal
	mkdir -p cleaned
	zcat /net/tmp/bojar/official-journal/hunaligned.singlepass.gz \
	| ~bojar/diplomka/umc/devel/tools/cleaning/clean_after_hunalignwrapper.pl \
	    --max-words=60 \
	| grep '^1-1	' \
	| gzip -c \
	> $@

cleaned/jolists.gz:
	# selecting usable sentences of eujournal list-like texts
	mkdir -p cleaned
	cat /net/me/merkur2/ufallabhome/galuscakova/umc/journal/aligned_lists \
	| sort -u \
	| grep -v '^[	0-9 [:punct:]]*$$' \
	| grep -v '	[0-9 [:punct:]]*$$' \
	| grep -v '^[0-9 [:punct:]]*	' \
	| sed 's/   */ /g' \
	| sed 's/^  *//g' \
	| sed 's/  *$$//g' \
	| sed 's/ *	 */	/' \
	| gzip -c \
	> $@

cleaned/ecnews.gz:
	# selecting usable sentences of news at ec.europa.eu
	mkdir -p cleaned
	zcat /net/me/merkur2/ufallabhome/galuscakova/umc/news-ec-europa-eu/aligned_corpora.txt.gz \
	| ~bojar/diplomka/umc/devel/tools/cleaning/clean_after_hunalignwrapper.pl \
	    --max-words=60 \
	| gzip -c \
	> $@
	
cleaned/ecweb.gz:
	# selecting usable sentences of the website ec.europa.eu
	# fixing some chars: Š<9f>
	mkdir -p cleaned
	cat /net/me/merkur2/ufallabhome/galuscakova/umc/ec-europa-eu/corpora_cs_en_version1.txt \
	| ~bojar/diplomka/umc/devel/tools/cleaning/clean_after_hunalignwrapper.pl \
	    --max-words=60 \
	| sed 's/â<82>¬  EUR   â<80>¦//g' \
	| perl -CSAD -pne 's/\xe2\x82\x{00ac}/\x{20ac}/g; s/\xed\x82 / /g; s/\xad//g; s/\x{160}\x{9f}/\x{015f}/g; s/\xe2\x80\xa2/-/g; s/\xe2\x80\x94/-/g; s/\xe2\x80\xa6/|/g; s/\xe2\x80\x91/-/g; s/\xe2\x{20ac}\x{160}\x93/\x{201c}/g; s/\xe2\x{20ac}\xef\xbf\xbd/\x{201d}/g;$$_' \
	| gzip -c \
	> $@
	

.PHONY: plaintext
plaintext:
	# avoid overwriting old
	if [ ! -e ../$(OUTCORPNAME)/$(OUTLANGNAME)_txt.gz ]; then \
	  mkdir -p ../$(OUTCORPNAME); \
	  set -o pipefail \
	  ; (ls $(SOURCES) || true) \
	  | grep '$(FILENAMERE)' \
	  | autocat --filelist=- \
	  | grep '$(COLUMNRE)' \
	  | cut -f $(COLIDX) \
	  | grep -v '^Đ.*Đ' \
	  | ./fix_whitespace.pl \
	  | remove_blank_lines \
	  | gzip -c > ../$(OUTCORPNAME)/$(OUTLANGNAME)_txt.gz || exit 1 ; \
	  zcat ../$(OUTCORPNAME)/$(OUTLANGNAME)_txt.gz \
	  | wc -l > ../$(OUTCORPNAME)/LINECOUNT || exit 1 ; \
	  echo untokenized > ../$(OUTCORPNAME)/$(OUTLANGNAME)_txt.info \
	    || exit 1 ; \
	else \
	  echo "Skipped existing ../$(OUTCORPNAME)/$(OUTLANGNAME)_txt.gz" ; \
	fi
# 
# .PHONY: analyze
# analyze: wmt10dev
# 	# avoid overwriting old
# 	[ ! -e ../$(OUTCORPNAME)/$(OUTLANG).gz ]
# 	mkdir -p ../$(OUTCORPNAME)
# 	# report tmt version
# 	echo srunblocks: $(SRUNBLOCKS) > ../$(OUTCORPNAME)/$(ANOTLANG).versions
# 	svnversion $$(dirname $$(dirname $$(dirname $(SRUNBLOCKS)))) \
# 	  >> ../$(OUTCORPNAME)/$(ANOTLANG).versions
# 	echo scenario: ../prep-wmt10/$(ANOTLANG)_$(SCENTYPE).scen \
# 	  >> ../$(OUTCORPNAME)/$(OUTLANG).versions
# 	# construct the corpus
# 	set -o pipefail \
# 	; ls $(CZENG09PLAINTEXTSDIR)/*.gz wmt10dev/*.gz extra/*.gz \
# 	| grep '$(FILENAMERE)' \
# 	| autocat --filelist=- \
# 	| grep '$(COLUMNRE)' \
# 	| cut -f $(LANGCOL-$(ANOTLANG)) \
# 	| qruncmd --jobs=$(JOBS) --join \
# 	    "$(SRUNBLOCKS) --errorlevel=FATAL $(ANOTLANG)_$(SCENTYPE).scen \
# 	        $(LANGNAME-$(ANOTLANG))_source_sentence factored_output" \
# 	| gzip -c > ../$(OUTCORPNAME)/$(OUTLANG).gz
# 	cp $(ANOTLANG)_$(SCENTYPE).info ../$(OUTCORPNAME)/$(OUTLANG).info

dumpfiles:
	@# dump what the regexes select from the corpora
	@set -o pipefail \
	; ls $(SOURCES) \
	| grep '$(FILENAMERE)'

dumplines:
	@# dump what the regexes select from the corpora
	@set -o pipefail \
	; ls $(SOURCES) \
	| grep '$(FILENAMERE)' \
	| autocat --filelist=- \
	| grep '$(COLUMNRE)'


# Peparation of plaintexts for WMT devsets
dev.tgz:
	wget http://www.statmt.org/wmt11/dev.tgz
test.tgz:
	wget http://www.statmt.org/wmt11/test.tgz
dev: dev.tgz test.tgz
	tar xzfv dev.tgz
	xzf test.tgz
	mv test/raw/news* dev/
	mv test/news* dev/
	oldrename news news- dev/news[^-]*
	rename 's/2011-src\.(..)\.raw/2011raw-src.$$1/' dev/news*raw*

dev.plaintext: dev
	mkdir -p $@
	for f in dev/*-src.{cz,cs,en}.sgm; do \
	  bn=`basename $$f | sed 's/cz/cs/; s/-src//;'`; \
	  pickre --pick --re='<seg.*?>\s*(.*?)\s*</seg>' \
	    < $$f \
	  | cut -f 1 \
	  | gzip -c > $@/$${bn//.sgm/.gz} ; \
	  echo "Saved $@/$${bn//.sgm/.gz}"; \
	done
	touch $@

wmt10dev: dev.plaintext
	mkdir -p $@
	for s in test2008 test2009 syscomb2009 test2010 test2011 test2011raw; do \
	  paste <(zcat $</news-$$s.en.gz)  <(zcat $</news-$$s.cs.gz) \
	  | prefix --tab $$s \
	  | gzip -c \
	  > $@/$$s.gz; \
	done



# seznamdata:
/ha/seznamdata/sents.gz: /ha/seznamdata/ftp/b-all.txt.converted.gz
	zcat $< \
	| ./select_czech_sents_from_seznamdata.pl \
	| gzip -c \
	> $@

/ha/seznamdata/200M.tok.gz: /ha/seznamdata/sents.gz
	cd /ha/seznamdata/ \
	&& zcat $< \
	| head -n 200000000 \
	| sort -u \
	| qruncmd --join --jobs=$(JOBS) \
	    '$(SRUNBLOCKS) \
	      "Miscel::SuicideIfMemFull TMT_PARAM_MEMLIMIT=20 \
	       Normalize_plaintext::Czech \
	       SCzechW_to_SCzechM::Tokenize_joining_numbers \
	       Print::Factored \
	         TMT_PARAM_PRINT_FACTORED=SCzechW \
		 TMT_PARAM_PRINT_FACTORED_DESTINATION=factored_output" \
	      czech_source_sentence factored_output --errorlevel FATAL' \
	| gzip -c > $@
/ha/seznamdata/next100M.tok.gz: /ha/seznamdata/sents.gz
	cd /ha/seznamdata/ \
	&& zcat $< \
	| skip 200000000 \
	| head -n 100000000 \
	| sort -u \
	| qruncmd --join --jobs=$(JOBS) \
	    '$(SRUNBLOCKS) \
	      "Miscel::SuicideIfMemFull TMT_PARAM_MEMLIMIT=20 \
	       Normalize_plaintext::Czech \
	       SCzechW_to_SCzechM::Tokenize_joining_numbers \
	       Print::Factored \
	         TMT_PARAM_PRINT_FACTORED=SCzechW \
		 TMT_PARAM_PRINT_FACTORED_DESTINATION=factored_output" \
	      czech_source_sentence factored_output --errorlevel FATAL' \
	| gzip -c > $@

