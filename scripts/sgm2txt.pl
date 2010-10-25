#!/usr/bin/perl
# Extracts plain text from sgm test files

use strict;

my $nl = 0;
while (<>) {
  $nl++;
  if (/<seg[^>]*>(.*?)<\/seg>/) {
    my $s = $1;
    s/\Q$&//; # remove the segment from the input
    $s =~ s/^\s*//;
    $s =~ s/\s*$//;
    print $s."\n";
  }
  die "$nl:Unexpected structure: $_"
    if /<\/?seg/;
}
