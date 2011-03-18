#!/usr/bin/perl
# composes the two alignments given in the first two columns to a single one

use strict;
use Getopt::Long;

my $debug = 0;
GetOptions(
  "debug" => \$debug,
) or exit 1;

while (<>) {
  chomp;
  my ($onestr, $twostr, $rest) = split /\t/, $_, 3;

  my $two;
  foreach my $p (grep {/./} split / /, $twostr) {
    my ($a, $b) = split /-/, $p;
    $two->{$a}->{$b} = 1;
  }

  my @out = ();
  foreach my $p (grep {/./} split / /, $onestr) {
    my ($a, $mid) = split /-/, $p;
    foreach my $b (sort keys %{$two->{$mid}}) {
      print STDERR " $a-$b" if $debug;
      push @out, "$a-$b";
    }
  }
  print STDERR "\n" if $debug;

  print join(" ", @out);
  print "\t$rest" if defined $rest;
  print "\n";
}

