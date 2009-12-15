# rules to create training and evaluation corpora for WMT10

all: configs make_all_configs.pl
	./make_all_configs.pl < $<

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
analyze:
	# avoid overwriting old
	[ ! -e ../$(OUTCORPNAME)/$(ANOTLANG).gz ]
	mkdir -p ../$(OUTCORPNAME)
	# report tmt version
	echo srunblocks: $(SRUNBLOCKS) > ../$(OUTCORPNAME)/$(ANOTLANG).versions
	svnversion $$(dirname $$(dirname $$(dirname $(SRUNBLOCKS)))) \
	  >> ../$(OUTCORPNAME)/$(ANOTLANG).versions
	echo scenario: ../prep-wmt10/$(ANOTLANG)_$(SCENTYPE).scen \
	  >> ../$(OUTCORPNAME)/$(ANOTLANG).versions
	# construct the corpus
	ls $(CZENG09PLAINTEXTSDIR)/*.gz \
	| grep '$(SECTIONRE)' \
	| autocat --filelist=- \
	| grep '$(DOMAINRE)' \
	| cut -f $(LANGCOL-$(ANOTLANG)) \
	| qruncmd --jobs=$(JOBS) --join \
	    "$(SRUNBLOCKS) $(ANOTLANG)_$(SCENTYPE).scen \
	        $(LANGNAME-$(ANOTLANG))_source_sentence factored_output" \
	| gzip -c > ../$(OUTCORPNAME)/$(ANOTLANG).gz
	cp $(ANOTLANG)_$(SCENTYPE).info ../$(OUTCORPNAME)/$(ANOTLANG).info
