#!/usr/bin/perl

use strict;

while (<>) {
  chomp;
  my @pairs = split / /, $_;
  print join(" ", map { my ($a, $b) = split /-/; "$b-$a" } @pairs);
  print "\n";
}
