#!/usr/bin/perl
# fix various weird whitespaces

use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while (<>) {
  s/\x{a0}/ /g;
  s/\s\s+/ /g;
  s/^ //;
  s/ $//;
  print;
}
