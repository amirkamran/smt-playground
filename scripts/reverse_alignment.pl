#!/usr/bin/perl
# Reverses alignment file, e.g. from en-cs to cs-en.
# Alignments are indices into the source and target sentences. They look like this:   "0-0 1-2 2-1 3-5".
# Obviously, if we switch translation direction, we need to change the above line to: "0-0 2-1 1-2 5-3".
# Copyright © 2010 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    s/\r?\n$//;
    my @pairs = split(/\s+/, $_);
    foreach my $p (@pairs)
    {
        $p =~ s/^(\d+)-(\d+)$/$2-$1/;
    }
    print(join(' ', @pairs), "\n");
}
