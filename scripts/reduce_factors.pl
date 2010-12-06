#!/usr/bin/perl
# Given a comma delimited list of factors, restricts the corpus at stdin
# to contain only these

use strict;

my $factors = shift;
*IN = *STDIN;
*OUT = *STDOUT;

my @INCLUDE = sort {$a <=> $b} split(/,/,$factors);
my $nr = 0;
while(<IN>) {
    $nr++;
    print STDERR "." if $nr % 10000 == 0;
    print STDERR "($nr)" if $nr % 100000 == 0;
    chomp; s/ +/ /g; s/^ //; s/ $//;
    my $first = 1;
    foreach (split) {
        my @FACTOR = split(/\|/);
        print OUT " " unless $first;
        $first = 0;
        my $first_factor = 1;
        foreach my $outfactor (@INCLUDE) {
          print OUT "|" unless $first_factor;
          $first_factor = 0;
          my $out = $FACTOR[$outfactor];
          die "Couldn't find factor $outfactor in token \"$_\" on line $nr" if !defined $out;
          print OUT $out;
        }
    } 
    print OUT "\n";
}
print STDERR "\n";
