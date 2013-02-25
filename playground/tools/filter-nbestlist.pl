#!/usr/bin/env perl
# given a "rules" file, removes all items from nbest list that are forbidden
#
# format of the rules file:
# 0||| word1 word2 word3
# sentid||| sequence of forbidden words

use strict;
use warnings;
use File::Path;
use File::Basename;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# there should be one option: preserve
# with two choices:
# - preserve a block of consecutive variants of a sentence, if the filtering
#   would remove all of them
# - preserve all candidates if filtering would remove all of them
#   (like above but instead of blockwise flush-style processing, read all
#   input)

my $rulesfile = shift;

my $pats;

my $rulesh = my_open($rulesfile);
while (<$rulesh>) {
  next if /^\s*#/ || /^\s*$/; # drop comments and blank lines
  chomp;
  die "Bad format: $_" if ! /^\s*([0-9]+)\s*\|\|\|\s*(.*)$/;
  my $sentid = $1;
  my $words = $2;
  $words =~ s/\s*$//;
  my @words = split /\s+/, $words;
  my $pattern = join(".*", map { "\Q $_ \E" } @words);
  my $oldpattern = $pats->{$sentid+1};
  if (!defined $oldpattern) {
    $oldpattern = "";
  } else {
    $oldpattern .= "|";
  }
  $oldpattern .= "$pattern";
  $pats->{$sentid+1} = $oldpattern;
  # print "Storing: $sentid+1 -> $oldpattern\n";
}

my $nr = 0;
my $removed = 0;
my $kept = 0;
while (<>) {
  $nr++;
  print STDERR "." if $nr % 100000 == 0;
  print STDERR "($nr)" if $nr % 1000000 == 0;
  chomp;
  next if /^\s*#/ || /^\s*$/; # drop comments and blank lines
  die "$nr:Bad format: $_" if ! /^\s*([0-9]+)\s*\|\|\|\s*(.*?)\|\|\|/;
  my $sentid = $1;
  my $sent = " ".$2." ";
  $sent =~ s/ /  /g;
  my $regex = $pats->{$sentid+1};
  # print "CHECKING $sent AGAINST $regex\n" if defined $regex;
  if (defined $regex && $sent =~ /$regex/) {
    # removing sentence, matches the forbidden
    $removed++;
  } else {
    print $_, "\n";
    $kept++;
  }
}
print STDERR "Processed $nr lines, removed $removed, kept $kept.\n";



sub my_open {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDIN, ":utf8");
    return *STDIN;
  }

  die "Not found: $f" if ! -e $f;

  my $opn;
  my $hdl;
  my $ft = `file '$f'`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat '$f' |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat '$f' |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

