#!/usr/bin/perl

# parse word alignments from Moses log file and output them in
# Giza++ format: 0-0 1-2...
#
# use with moses -v 2

use strict;
use warnings;

while (<>) {
    my $matched = 0;
    while ($_ =~ m/\[\[([0-9]+)\.\.([0-9]+)\]/g) {
        print "$1-$2 ";
        $matched = 1;
    }
    print "\n" if $matched;
}
