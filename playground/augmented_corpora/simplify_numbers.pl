#!/usr/bin/perl

use strict;

while (<>) {
  chomp;
  my @toks = split /\s+/;
  my @out = ();
  foreach my $tok (@toks) {
    if ($tok =~ /^1[789][0-9][0-9]$/ || $tok =~ /^20[0-9][0-9]$/) {
      # year-like
      push @out, "4444";
    } else {
      $tok =~ y/0123456789/5555555555/;
      push @out, $tok;
    }
  }
  print join(" ", @out);
  print "\n";
}

