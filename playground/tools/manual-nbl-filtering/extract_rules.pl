#!/usr/bin/perl
# extract and emit rules from a marked nbestlist

use strict;
use warnings;
use File::Path;
use File::Basename;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $nr = 0;
while (<>) {
  $nr++;
  next if /^\s*#/ || /^\s*$/; # drop comments and blank lines
  chomp;
  die "Bad format: $_" if ! /^\s*([0-9]+)\s*\|\|\|\s*(.*)$/;
  my $sentid = $1;
  my $words = $2;

  my @forb = ();
  while ($words =~ /\*\*\*(.*?)\*\*\*/) {
    my $forb = $1;
    $words =~ s/\E\*\*\*$forb\*\*\*\Q//;
    $forb =~ s/^\s*//;
    $forb =~ s/\s*$//;
    $forb =~ s/\s+/---/g;
    # print "$nr:$sentid ||| $forb\n";
    push @forb, $forb;
  }
  print "$sentid ||| ", join(" ", @forb), "\n" unless 0 == scalar @forb;
}
