#!/usr/bin/perl
# Low-level (almost) language-independent UTF-8 tokenizer.
# (c) 2007 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    # Replace any control and space characters (including TAB, &nbsp;) by spaces.
    # No worry about the line breaks - we work within one line.
    s/\r?\n$//;
    s/[\s\x{A0}\x{0}-\x{1F}\x{80}-\x{9F}]+/ /g;
    # SGML entities (e.g. "&nbsp;") are not suitable for escaping because of ampersand and semicolon.
    # They are punctuation characters and will be separated from their surroundings.
    # So we use control characters \x{1} and \x{0} - the above substitution guarantees there will be no collision.
    # Protect periods and commas before numbers.
    s/\.(\d)/\x{1}period\x{0}$1/g;
    s/,(\d)/\x{1}comma\x{0}$1/g;
    # Surround punctuation by spaces. ###!!! Průšvih! Tohle nám rozloží i entity! (& comma ;)
    s/(\pP)/ $1 /g;
    # Remove redundant spaces.
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /g;
    # De-escape protected characters.
    s/\x{1}period\x{0}/./g;
    s/\x{1}comma\x{0}/,/g;
    # Print the modified line. Remember, we erased the line break.
    print("$_\n");
}
