# rules to create training and evaluation corpora for WMT10

# BUGS:
#   Empty line:
#   czeng09-te/cs.gz         101262
#   ...a to proto, ze ceska veta obsahuje jeden znak: 0
#   techdoc-b167886-08train-f012678-s13     Nil     0

SHELL=/bin/bash

all: analyze.czeng copy_plaintexts
plaintexts: plaintext.czeng copy_plaintexts
	make plaintext.wmt10dev
	make plaintext.extra

plaintext.%: configs.% make_all_configs.pl
	./make_all_configs.pl --target=plaintext < $<
	touch $@

../wmt09mono:
	# create plaintext of wmt09 monolingual czech texts
	mkdir $@
	ln -s /export/data/WMT-2009/training/news-train08.cz.gz $@/cs_txt.gz
	echo untokenized > $@/cs_txt.info
	zcat $@/cs_txt.gz | wc -l > $@/LINECOUNT

TRTOK=/home/bojar/diplomka/umc/devel/tools/tokenizer/trainable_tokenizer
../syn200x:
	# create plaintext of syn2000, 2005 and 2006pub monolingual czech texts
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
	# now tokenize
	### horribly slow and segfaults
	#qruncmd --jobname=synsegment --jobs=$(JOBS) \
	#    '$(TRTOK) data-cs --detokenize --group=line | remove_blank_lines' \
	#    $@/cs_unseg.gz \
	#| gzip -c > $@/cs_txt.gz
	qruncmd --jobname=synsegment --jobs=$(JOBS) \
	    '$(SRUNBLOCKS) SCzechW_to_SCzechM::TextSeg_tokenizer_and_segmenter --store-input-to=document czech_source_text czech_source_sentence --allow-many-output-bundles ' \
	    $@/cs_unseg.gz \
	| gzip -c > $@/cs_txt.gz
	echo untokenized > $@/cs_txt.info
	zcat $@/cs_txt.gz | wc -l > $@/LINECOUNT


analyze.%: configs.% make_all_configs.pl
	./make_all_configs.pl < $<
	touch $@

copy_plaintexts: dev.plaintext
	for y in 08 09; do \
	  for l in cs en; do \
	    cp $</news-test20$$y.$$l.gz ../wmt102.test$$y/$$l"PLAIN".gz \
	        || exit 1 ; \
	  done ; \
	done

CZENG09PLAINTEXTSDIR=/net/data/czeng09-public-release/data-plaintext/

#SRUNBLOCKS=~bojar/diplomka/granty/emplus/wmt10/playground/workspace.20091113-2336/tmt/devel/tools/srunblocks_streaming/srunblocks
SRUNBLOCKS=~bojar/diplomka/granty/emplus/wmt10/playground/workspace.20091113-2336/tmt2/tools/srunblocks_streaming/srunblocks


JOBS?=40

# outdated: hardwired config
czeng09-s00:
	# avoid overwriting old
	[ ! -d ../$@ ]
	mkdir ../$@
	# construct czech
	zcat $(CZENG09PLAINTEXTSDIR)/00train.gz \
	| cut -f 3 \
	| qruncmd --jobs=$(JOBS) --join \
	    "$(SRUNBLOCKS) --errorlevel=FATAL \
	      cs_a.scen czech_source_sentence factored_output" \
	| gzip -c > ../$@/cs.gz
	echo "form|lemma|tag|ord|gov|afun" > ../$@/cs.info

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

.PHONY: plaintext
plaintext: wmt10dev
	# avoid overwriting old
	if [ ! -e ../$(OUTCORPNAME)/$(ANOTLANG)_txt.gz ]; then \
	  mkdir -p ../$(OUTCORPNAME); \
	  set -o pipefail \
	  ; ls $(CZENG09PLAINTEXTSDIR)/*.gz wmt10dev/*.gz extra/*.gz \
	  | grep '$(FILENAMERE)' \
	  | autocat --filelist=- \
	  | grep '$(COLUMNRE)' \
	  | cut -f $(LANGCOL-$(ANOTLANG)) \
	  | gzip -c > ../$(OUTCORPNAME)/$(ANOTLANG)_txt.gz || exit 1 ; \
	fi

.PHONY: analyze
analyze: wmt10dev
	# avoid overwriting old
	[ ! -e ../$(OUTCORPNAME)/$(OUTLANG).gz ]
	mkdir -p ../$(OUTCORPNAME)
	# report tmt version
	echo srunblocks: $(SRUNBLOCKS) > ../$(OUTCORPNAME)/$(ANOTLANG).versions
	svnversion $$(dirname $$(dirname $$(dirname $(SRUNBLOCKS)))) \
	  >> ../$(OUTCORPNAME)/$(ANOTLANG).versions
	echo scenario: ../prep-wmt10/$(ANOTLANG)_$(SCENTYPE).scen \
	  >> ../$(OUTCORPNAME)/$(OUTLANG).versions
	# construct the corpus
	set -o pipefail \
	; ls $(CZENG09PLAINTEXTSDIR)/*.gz wmt10dev/*.gz extra/*.gz \
	| grep '$(FILENAMERE)' \
	| autocat --filelist=- \
	| grep '$(COLUMNRE)' \
	| cut -f $(LANGCOL-$(ANOTLANG)) \
	| qruncmd --jobs=$(JOBS) --join \
	    "$(SRUNBLOCKS) --errorlevel=FATAL $(ANOTLANG)_$(SCENTYPE).scen \
	        $(LANGNAME-$(ANOTLANG))_source_sentence factored_output" \
	| gzip -c > ../$(OUTCORPNAME)/$(OUTLANG).gz
	cp $(ANOTLANG)_$(SCENTYPE).info ../$(OUTCORPNAME)/$(OUTLANG).info

dump:
	@# dump what the regexes select from the corpora
	@set -o pipefail \
	; ls $(CZENG09PLAINTEXTSDIR)/*.gz wmt10dev/*.gz\
	| grep '$(FILENAMERE)' \
	| autocat --filelist=- \
	| grep '$(COLUMNRE)'


dev.tgz:
	wget http://www.statmt.org/wmt10/dev.tgz
dev: dev.tgz
	tar xzfv dev.tgz
	oldrename news news- dev/news[^-]*

dev.plaintext: dev
	mkdir -p $@
	for f in dev/*-src.{cz,en}.sgm; do \
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
	for s in test2008 test2009 syscomb2009; do \
	  paste <(zcat $</news-$$s.en.gz)  <(zcat $</news-$$s.cs.gz) \
	  | prefix --tab $$s \
	  | gzip -c \
	  > $@/$$s.gz; \
	done



