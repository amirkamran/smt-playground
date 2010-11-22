#!/usr/bin/perl

# parse word alignments from Moses log file and output them in
# Giza++ format: 0-0 1-2...
#
# use with moses -v 2

# parsing this format:
# [[0..0]:the :0-0 : pC=-3.53548, c=-4.80458] [[1..1]:procedure :0-0 : pC=-0.527404, c=-3.62432] 

use strict;
use warnings;

while (<>) {
    if ($_ !~ m/^\[\[/) {
        next;
    }
    chomp;
    my @phrases = split /\] \[/;
    my $offset_tgt = 0;
    my $offset_src = 0;
    my $next_offset_tgt = 0;
    foreach (@phrases) {
        $_ =~ m/\[[0-9]+\.\.([0-9]+)\]:(.+):([^:]*):[^:]+/;
        my @words = split(" ", $2);
        $offset_src = $1;
        $offset_tgt = $next_offset_tgt;
        $next_offset_tgt += scalar(@words);
        if (!$3) { # no alignment points, nothing to do
            next;
        }
        my @alignment_points = split(" ", $3);
        foreach (@alignment_points) {
            $_ =~ m/([0-9]+)-([0-9]+)/;
            my $src = $1 + $offset_src;
            my $tgt = $2 + $offset_tgt;
            print "$src-$tgt ";
        }
    }
    print "\n";
}
