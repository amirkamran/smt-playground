#!/usr/bin/perl
# Reads sgm format of WMT test sets and emits two columns:
# 1. indicates headline/body part of the document
# 2. indicates the original language en/cs/ru...

use strict;

my $section = "undef";
my $origlang = "undef";
while (<>) {
  if (/<doc .*origlang=["'](..)["']/) {
    $origlang = $1;
    $origlang = "cs" if $origlang eq "cz"; # canonic name!
    $section = "headline";
  }
  if (/<\/h[l1]/i) {
    $section = "body";
  }
  if (/<seg /) {
    print "$section\t$origlang\n";
  }
}

