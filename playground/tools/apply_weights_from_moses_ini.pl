#!/usr/bin/perl
# merges two moses.ini files, taking weights from one of them

use strict;

my $weightsf = shift;

die "usage: $0 moses.ini-with-weights < moses.ini > new-moses.ini"
  if ! defined $weightsf;

open WF, $weightsf or die "Can't read $weightsf";
my $weights;
my $section = undef;
while (<WF>) {
  chomp;
  if (/^\[([^]]+)\]/) {
    $section = $1;
    next;
  }
  if (defined $section && /^([-0-9.e]+)$/) {
    # collect the weight
    push @{$weights->{$section}}, $_;
    next;
  }
  $section = undef;
}
close WF;

# read the input moses.ini any apply the weights
my $section = undef;
my @w = ();
my $nl = 0;
while (<>) {
  $nl++;
  if (/^\[([^]]+)\]/) {
    $section = $1;
    @w = @{$weights->{$section}} if defined $weights->{$section};
    print;
    next;
  }
  if (defined $section && /^([-0-9.e]+)$/) {
    # replace the weight
    my $w = shift @w;
    print "$w\n";
    next;
  }
  $section = undef if 0 == scalar @w; # autoleave the current section
  die "$nl:Unexpected line '$_' when applying weights for $section"
    if defined $section;
  print;
}
