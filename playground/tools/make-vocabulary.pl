#!/usr/bin/env perl

# Creates lexicons with word IDs and word frequencies,
# used for e.g. global lexicon models.
# Implemented by Jiri Marsik

# Taken from mosesdecoder/scripts/training/train-model.perl

use strict;
use Getopt::Long "GetOptions";

&get_vocabulary();

sub get_vocabulary {
    my %WORD;
    while(<STDIN>) {
        chop;
        foreach (split) { $WORD{$_}++; }
    }

    my @NUM;
    foreach my $word (keys %WORD) {
        my $vcb_with_number = sprintf("%07d %s",$WORD{$word},$word);
        push @NUM,$vcb_with_number;
    }

    print "1\tUNK\t0\n";
    my $id=2;
    foreach (reverse sort @NUM) {
        my($count,$word) = split;
        printf "%d\t%s\t%d\n",$id,$word,$count;
        $id++;
    }
}
