#!/usr/bin/perl
# Adds an extra score to the phrase table penalizing various easy-to-judge suspicious items

use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while (<>) {
  chomp;
  my $line = $_;
  my ($src, $tgt, $ali1, $ali2, $scores) = split / \|\|\| /;
  my $newscore = 0.0;

  # only one of them is only punct
  $newscore++ if $src =~ /^[[:space:][:punct:]]*$/ xor $tgt =~ /^[[:space:][:punct:]]*$/;

  # only one of them is numbers and punct
  $newscore++ if $src =~ /^[[:space:][:digit:][:punct:]]*$/ xor $tgt =~ /^[[:space:][:digit:][:punct:]]*$/;

  # they contain different numbers (i.e. sequences of digits
  my $srcd = trim($src);
  $srcd =~ tr/0-9/ /cs;
  my $tgtd = trim($tgt);
  $tgtd =~ tr/0-9/ /cs;
  $newscore++ if $tgtd ne $srcd;

  # and one more point if the sequence of digits is different
  $srcd =~ tr/0-9//dc;
  $tgtd =~ tr/0-9//dc;
  $newscore++ if $tgtd ne $srcd;

  print $line;
  print " ";
  printf("%.3g", exp($newscore));
  print "\n";
}

sub trim {
  my $s = shift;
  $s =~ s/^\s+//;
  $s =~ s/\s+$//;
  return $s;
}
