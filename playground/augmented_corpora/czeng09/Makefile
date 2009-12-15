all:
	qsubmake cs.gz
	qsubmake en.gz

CZENGEXPORTEDDIR= /net/data/czeng09-public-release/data-export-format/

cs.gz:
	zcat $(CZENGEXPORTEDDIR)/*.gz \
	| head \
	| ./add_t_factors.pl --langcol=5 \
	| gzip -c \
	> $@

DIRBASE=../czeng09

SECTIONS=e f na ne p s

section.%.cs.gz:
	mkdir -p $(DIRBASE)-$*
	zcat $(CZENGEXPORTEDDIR)/*.gz \
	| grep '^$*' \
	| cut -f6 \
	| gzip -c \
	> $(DIRBASE)-$*/cs.gz
	cp cs-a.info $(DIRBASE)-$*/cs.info


