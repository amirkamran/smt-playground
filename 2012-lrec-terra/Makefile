all: article.pdf

proposal.pdf: refs.bib article.tex

LATEX=pdflatex

%.pdf: %.tex
	$(LATEX) $<
	bibtex $* || echo "Bibtex failed"
	lim=4; \
	  while [ $$lim -ge 0 ] \
	      && grep 'Rerun to get cross-references right.\|Citation.*undefined' $*.log >/dev/null 2>/dev/null; do \
	    $(LATEX) $< ; \
	    lim=$$(($$lim - 1)) ; \
	  done
	$(LATEX) $<

clean:
	rm -f article.log article.aux article.bbl article.blg article.pdf

