#!/usr/bin/perl
# Capitalizes the first word of each sentence (line) (which was typically lowercased in MT output).
# If the first token is punctuation (such as bracket or quotation mark), finds the first non-punctuation character (could be a digit).
# In theory the script should work for both tokenized and detokenized input.
# Side-effect: removes leading space characters, if any (but there should be none!)
# Copyright © 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    s/^\s*//;
    s/^(.*?)(\PP)/$1\u$2/;
    print;
}
