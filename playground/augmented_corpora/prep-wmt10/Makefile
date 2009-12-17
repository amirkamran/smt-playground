# rules to create training and evaluation corpora for WMT10

SHELL=/bin/bash

all: analyze.czeng

analyze.%: configs.% make_all_configs.pl
	./make_all_configs.pl < $<
	touch $@

CZENG09PLAINTEXTSDIR=/net/data/czeng09-public-release/data-plaintext/

SRUNBLOCKS=~bojar/diplomka/granty/emplus/wmt10/playground/workspace.20091113-2336/tmt/devel/tools/srunblocks_streaming/srunblocks


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
	    "$(SRUNBLOCKS)\
	      cs_a.scen czech_source_sentence factored_output" \
	| gzip -c > ../$@/cs.gz
	echo "form|lemma|tag|ord|gov|afun" > ../$@/cs.info

# Generic analyzer

OUTCORPNAME?=czeng09-s00
ANOTLANG?=cs
OUTLANG?=$(ANOTLANG)
SCENTYPE?=a
SECTIONRE?=00
#SECTIONRE?=[0-79][0-9]
DOMAINRE?=.

LANGCOL-cs=3
LANGCOL-en=2
LANGNAME-cs=czech
LANGNAME-en=english
test:
	echo $(LANGCOL-$(ANOTLANG))
	echo $(LANGNAME-$(ANOTLANG))

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
	; ls $(CZENG09PLAINTEXTSDIR)/*.gz wmt10dev/*.gz\
	| grep '$(SECTIONRE)' \
	| autocat --filelist=- \
	| grep '$(DOMAINRE)' \
	| cut -f $(LANGCOL-$(ANOTLANG)) \
	| qruncmd --jobs=$(JOBS) --join \
	    "$(SRUNBLOCKS) $(ANOTLANG)_$(SCENTYPE).scen \
	        $(LANGNAME-$(ANOTLANG))_source_sentence factored_output" \
	| gzip -c > ../$(OUTCORPNAME)/$(OUTLANG).gz
	cp $(ANOTLANG)_$(SCENTYPE).info ../$(OUTCORPNAME)/$(OUTLANG).info

dump:
	# dump what the regexes select from the corpora
	set -o pipefail \
	; ls $(CZENG09PLAINTEXTSDIR)/*.gz wmt10dev/*.gz\
	| grep '$(SECTIONRE)' \
	| autocat --filelist=- \
	| grep '$(DOMAINRE)'


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

wmt10dev: dev.plaintext
	mkdir -p $@
	for s in test2008 test2009 syscomb2009; do \
	  paste <(zcat $</news-$$s.en.gz)  <(zcat $</news-$$s.cs.gz) \
	  | prefix --tab $$s \
	  | gzip -c \
	  > $@/$$s.gz; \
	done



