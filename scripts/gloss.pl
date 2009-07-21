#!/usr/bin/perl
# Read stdin and gloss every word using a probabilistic dictionary

use strict;
use Getopt::Long;

my $dict = "$0.dict";
my $srccorp = undef;
my $tgtcorp = undef;
my $alicorp = undef;
my $reverse = 0;
my $cutoff = 3;

GetOptions(
  "src=s" => \$srccorp,
  "tgt=s" => \$tgtcorp,
  "ali=s" => \$alicorp,
  "rev|reverse" => \$reverse, # reverse the alignment
  "c|cutoff=i" => \$cutoff,
) or exit 1;

my $dict = undef;

if (defined $srccorp || defined $tgtcorp || defined $alicorp || ! -e $dict) {
  die "usage to collect dictionary: $0 --src=F --tgt=F --ali=F [--dict=F]"
    if !defined $srccorp || !defined $tgtcorp || !defined $alicorp;
  my $srch = my_open($srccorp);
  my $tgth = my_open($tgtcorp);
  my $alih = my_open($alicorp);
  while (<$alih>) {
    my $sline = <$srch>;
    die "$srccorp:Too short!" if !defined $sline;
    my $tline = <$tgth>;
    die "$tgtcorp:Too short!" if !defined $tline;
    chomp $sline;
    my @swords = split /\s+/, $sline;
    chomp $tline;
    my @twords = split /\s+/, $tline;
    chomp;
    foreach my $pair (split /\s+/) {
      my ($s, $t) = split /-/, $pair;
      my $sw = $swords[$s];
      die "$srccorp:Bad alignment" if !defined $sw;
      my $tw = $twords[$t];
      die "$tgtcorp:Bad alignment" if !defined $tw;
      if ($reverse) {
        $dict->{$tw}->{$sw} ++;
      } else {
        $dict->{$sw}->{$tw} ++;
      }
    }
  }
  my $sline = <$srch>;
  die "$srccorp:Too long!" if defined $sline;
  my $tline = <$tgth>;
  die "$tgtcorp:Too long!" if defined $tline;

  # now save the dictionary, applying cuttoff
  XXX
}



sub my_open {
  my $f = shift;
  die "Not found: $f" if ! -e $f;

  my $opn;
  my $hdl;
  my $ft = `file $f`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat $f |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat $f |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

sub my_save {
  my $f = shift;

  my $opn;
  my $hdl;
  # file might not recognize some files!
  if ($f =~ /\.gz$/) {
    $opn = "| gzip -c > $f";
  } elsif ($f =~ /\.bz2$/) {
    $opn = "| bzip2 > $f";
  } else {
    $opn = "> $f";
  }
  open $hdl, $opn or die "Can't write to '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}
