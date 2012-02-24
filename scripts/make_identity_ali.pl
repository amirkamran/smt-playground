#!/usr/bin/perl
# constructs 1-1 alignment file for a given input

use strict;

while (<>) {
  my @toks = split /\s+/;
  print join(" ", map { "$_-$_" } (0..$#toks));
  print "\n";
}
