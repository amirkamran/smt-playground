#!/usr/bin/perl
# fix various weird whitespaces

use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while (<>) {
  s/[\x0d\x{a0}\x{f0b7}\x{f024}\x{2028}\x{2001}\x{2002}\x{2003}\x{2004}\x{2005}\x{2006}\x{2007}\x{2008}\x{2009}\x{200a}\x{3000}\x85]/ /g;
  s/[ \t][ \t]+/ /g;
  s/^ //;
  s/ $//;
  print;
}
