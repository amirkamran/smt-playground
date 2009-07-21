#!/usr/bin/perl
# Normalizes Unicode text: chooses one way of writing phenomena that can be written several ways.
# Beware 1: most changes cannot be reversed!
# Beware 2: normalization can affect tokenization! (There could be a token consisting solely of garbage characters.)
# Originally written for Devanagari script (Hindi) but can be extended to other languages.
# Copyright © 2008, 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
#                        minor fixes by Ondrej Bojar
# License: GNU GPL

# NOTE: We may also want to perform the following changes if we do not mind that they change tokenization:
# NO-BREAK SPACE (\x{A0}) -> SPACE (\x{20})

use strict;
use utf8;
use Unicode::Normalize;
use open ":utf8";

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# Are we allowed to change tokenization? (Do not fix it unless you know your data are fine.)
my $fixed_tokenization = 0;

while(<>)
{
    # If the tokenization shall be fixed we must note the original number of tokens.
    my $n_before = scalar(split(/\s+/, $_));
    my $before = $_;
    # Convert to Unicode canonic decomposition
    # this also separates Devanagari Nukta characters from the preceding char
    $_ = NFD($_);
    # Discard or replace control characters (code < 20 or between 127 and 159).
    s/[ \t]+/ /g;
    s/[\x{00}-\x{08}\x{0B}-\x{1F}]//g;
    s/[\x{7F}-\x{9F}]//g;
    # Discard the special characters and non-characters at the end of the 2-byte space.
    s/[\x{FEFF}\x{FFF0}-\x{FFFF}]//g;
    # Remove zero width joiner (v některých datech se objevuje za virámem).
    s/\x{200D}//g;
    # Replace typographic variants of punctuation by ASCII counterparts.
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
    s/[\[\{]/(/g; # OPENING BRACKETS
    s/[\]\}]/)/g; # CLOSING BRACKETS
    s/\x{2021}/#/g; # DOUBLE DAGGER
    s/\x{2022}/*/g; # BULLET
    s/\x{2023}/*/g; # TRIANGULAR BULLET
    s/\x{2024}/./g; # ONE DOT LEADER
    s/\x{2025}/../g; # TWO DOT LEADER
    s/\x{2026}/.../g; # HORIZONTAL ELLIPSIS
    s/[\x{2027}-\x{202F}]//g; # HYPHENATION POINT to RIGHT-TO-LEFT OVERRIDE

    # Discard devanagari nuktas.
    s/\x{93C}//g;

    # Replace candrabindu by anusvara.
    s/\x{901}/\x{902}/g;
    # Replace danda and double danda by full stop.
    # Same for devanagari abbreviation sign.
    s/[\x{964}\x{965}\x{970}]/./g;
    # Replace devanagari digits by European digits.
    tr/\x{966}\x{967}\x{968}\x{969}\x{96A}\x{96B}\x{96C}\x{96D}\x{96E}\x{96F}/0123456789/;
    # Check the number of tokens after the transformations.
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
