#!/usr/bin/env perl

# This program contains most of the code from statmt/scripts/charnormal.pl
# written by Dan Zeman.

# This program is mainly written for normalizing some Tamil
# vowel combinations. The rest of the functionality is almost similar to
# the original code.

# Usage: cat tamil-transliterated.txt |./charnormal-tamil.pl > normalized.txt

use strict;
use warnings;
use utf8;

use Unicode::Normalize;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $fixed_tokenization = 0;

while (<>) {
    
    my $n_before = scalar(split(/\s+/, $_));
    my $before = $_;    
    
    # normalization of Tamil vowel signs    
    # combines vowel sign 'e' and 'aa' into vowel sign 'o'
    s/(nj|ng|k|c|t|N|T|w|p|m|y|r|l|v|L|z|R|n)e\x{0BBE}/$1o/g; 
    # combines vowel sign 'ee' and 'aa' into vowel sign 'oo'
    s/(nj|ng|k|c|t|N|T|w|p|m|y|r|l|v|L|z|R|n)E\x{0BBE}/$1O/g;
    
    s/\x{2010}/-/g; # HYPHEN
    s/\x{2011}/-/g; # NON-BREAKING HYPHEN
    s/\x{2012}/-/g; # FIGURE DASH
    s/\x{2013}/-/g; # EN DASH
    s/\x{2014}/-/g; # EM DASH
    s/\x{2015}/-/g; # HORIZONTAL BAR
    s/\x{2016}/||/g; # DOUBLE VERTICAL LINE
    s/\x{2017}/_/g; # DOUBLE LOW LINE
    s/\x{2018}/'/g; # LEFT SINGLE QUOTATION MARK
    s/\x{2019}/'/g; # RIGHT SINGLE QUOTATION MARK
    s/\x{201A}/'/g; # SINGLE LOW-9 QUOTATION MARK
    s/\x{201B}/'/g; # SINGLE HIGH-REVERSED-9 QUOTATION MARK
    s/\x{201C}/"/g; # LEFT DOUBLE QUOTATION MARK
    s/\x{201D}/"/g; # RIGHT DOUBLE QUOTATION MARK
    s/\x{201E}/"/g; # DOUBLE LOW-9 QUOTATION MARK
    s/\x{201F}/"/g; # DOUBLE HIGH-REVERSED-9 QUOTATION MARK
    s/\x{2020}/+/g; # DAGGER
    s/\x{2021}/#/g; # DOUBLE DAGGER
    s/\x{2022}/*/g; # BULLET
    s/\x{2023}/*/g; # TRIANGULAR BULLET
    s/\x{2024}/./g; # ONE DOT LEADER
    s/\x{2025}/../g; # TWO DOT LEADER
    s/\x{2026}/.../g; # HORIZONTAL ELLIPSIS
    
    s/\x{2032}/'/g; # PRIME
    s/\x{2033}/"/g; # DOUBLE PRIME
    s/\x{2035}/'/g; # REVERSED PRIME
    s/\x{2036}/"/g; # REVERSED DOUBLE PRIME
    
    if($fixed_tokenization)
    {
        my $n_after = scalar(split(/\s+/, $_));
        if($n_after != $n_before)
        {
            die("The transformations changed the number of tokens (before $n_before, after $n_after).\nLine before: $before\nLine after : $_\n");
        }
    }
    print;    
}
