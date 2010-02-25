#!/usr/bin/perl
# strips funny suffixes of Czech lemmas
# *including* word sense number, i.e. stát-1 ---> stát

use strict;

my $nr = 0;
while (<>) {
  $nr++;
  chomp;
  my @lems = split / /;
  map {
      s/(.)[-;`_].*/$1/;
      $_;
    } @lems;
  my $out = join(" ", @lems);
  die "$nr:Lost word: $out" if $out =~ /  /;
  print $out."\n";
}
