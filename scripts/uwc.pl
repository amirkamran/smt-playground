#!/usr/bin/perl
# Counts lines, tokens and characters of an UTF-8 text.
# Counts unicode characters, not bytes!
# (You might be able to get similar result using normal "wc" if your LOCALE is set up for UTF-8.)
# Unlike normal wc, this one counts several consecutive blank characters as one space.
# Copyright © 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    # Remove the line break.
    s/\r?\n$//;
    # Remove any superfluous spaces.
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /g;
    # Count lines (segments), tokens and characters.
    $nl++;
    my @tokens = split(/\s+/, $_);
    $nt += scalar(@tokens);
    # Add one character for the space at the end of the line.
    $nc += length($_)+1;
}
print("lines = $nl\n");
print("tokens = $nt\n");
print("characters = $nc\n");
print("normopages = ", $nc/1800, "\n");
