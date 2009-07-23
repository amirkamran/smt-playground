Preprocessing Tools
===================
written by Philipp Koehn, Josh Schroeder, Dan Zeman, and others...
based on the tools available at http://www.statmt.org/europarl
also the StatMT SVN repository at http://svn.ms.mff.cuni.cz/projects/statmt/


Detokenizer
===========
Usage ./detokenizer.pl -l [en|de|...] < tokenizedfile > detokenizedfile

Used after decoding, removes most spaces inserted by tokenizer.pl.


Lowercaser
==========
Usage ./lowercase.pl < tokenizedfile > lowercasedfile

Guess what this one does.


Reuse Weights
=============
./reuse-weights.pl weights.ini < moses.ini > weighted.ini

Combines feature weights in weights.ini with phrase-tables, LMs
and reordering-tables specified in moses.ini to make weighted.ini


Sentence Splitter
=================
Usage ./split-sentences.pl -l [en|de|...] < textfile > splitfile

Uses punctuation and Capitalization clues to split paragraphs of 
sentences into files with one sentence per line. For example:

This is a paragraph. It contains several sentences. "But why," you ask?

goes to:

This is a paragraph.
It contains several sentences.
"But why," you ask?

See more information in the Nonbreaking Prefixes section.


Tokenizer
=========
Usage ./tokenizer.pl -l [en|de|...] < textfile > tokenizedfile

Splits out most punctuation from words. Special cases where splits
do not occur are documented in the code. 

This E.U. treaty is, to use the words of Mr. Smith, "awesome." 

goes to:

This E.U. treaty is , to use the words of Mr. Smith , " awesome . "

See more information in the Nonbreaking Prefixes section.


XML Wrapper
===========
Usage ./wrap-xml.pl xml-frame language [system-name] < translatedfile > wrappedfile.sgm

Using the doc, sent, and other tags specified in the xml-frame, 
creates a NIST-compatile SGM file tagged with the specified 
language and system whose contents are from translatedfile.


Nonbreaking Prefixes Directory
==============================

Nonbreaking prefixes are loosely defined as any word ending in a
period that does NOT indicate an end of sentence marker. A basic
example is Mr. and Ms. in English.

The sentence splitter and tokenizer included with this release
both use the nonbreaking prefix files included in this directory.

To add a file for other languages, follow the naming convention
nonbreaking_prefix.?? and use the two-letter language code you
intend to use when calling split-sentences.perl and tokenizer.perl.

Both split-sentences and tokenizer will first look for a file for the
language they are processing, and fall back to English if a file
for that language is not found. If the nonbreaking_prefixes directory does
not exist at the same location as the split-sentences.perl and tokenizer.perl
files, they will not run.

For the splitter, normally a period followed by an uppercase word
results in a sentence split. If the word preceeding the period
is a nonbreaking prefix, this line break is not inserted.

For the tokenizer, a nonbreaking prefix is not separated from its 
period with a space.

A special case of prefixes, NUMERIC_ONLY, is included for special
cases where the prefix should be handled ONLY when before numbers.
For example, "Article No. 24 states this." the No. is a nonbreaking
prefix. However, in "No. It is not true." No functions as a word.

See the example prefix files included here for more examples.


Dan's Tokenizer
===============
Usage ./tok-dan.pl < text.txt > tokenized_text.tok.txt

Language-independent low-level tokenizer by Dan Zeman.
Unlike the tokenizer above, this one splits tokens on hyphens, too.


Unicode Character Normalization
===============================
Usage $STATMT/scripts/charnormal.pl < input.txt > output.txt

Normalizes UTF-8 text to canonical form. If a character can be encoded in more
than one way, as e.g. "DEVANAGARI LETTER QA" (either as U+0958, or as (U+0915,
"DEVANAGARI LETTER KA", and U+093C, "DEVANAGARI SIGN NUKTA")), this script
guarantees that always the same way will be selected.

The script was originally written just for Devanagari (and called devnormal.pl)
but it now contains changes that affect all scripts. For Devanagari, it also
removes some information that was deemed impeding in MT but is meaningful
otherwise (example: converting "DEVANAGARI SIGN CANDRABINDU" to "DEVANAGARI
SIGN ANUSVARA"). This aspect of the normalization can be compared to
lowercasing of Latin script. People might want to "recase" the output.

Beware: as a result of normalization, the number of tokens can change (usually
decrease)! This can even result in an empty sentence, that should be removed
but the script cannot remove it because it only operates on one side of the
parallel corpus.

Other changes the script does:
* converts Devanagari digits to Arabic (European), i.e. ०१२३४५६७८९ to 0123456789
* converts Devanagari danda ("।") and double danda ("॥") to period (".")
* converts Devanagari abbreviation sign ("॰") to period (".")
* removes the zero-width joiners ("\x{200D}")


Frequency dictionary
====================
Usage ./freqdict.pl < text.txt > freqdict.txt

Reads tokenized text and writes a dictionary of tokens found in the text,
in descending order of their frequency. Can be used to find possible
stopwords.
