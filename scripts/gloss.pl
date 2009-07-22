#!/usr/bin/perl
# Read stdin and gloss every word using a probabilistic dictionary
#
# Ondrej Bojar

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $there = ">";
my $reverse = "<";
my $dictfile = "$0.dict.gz";
my $srccorp = undef;
my $tgtcorp = undef;
my $alicorp = undef;
my $cutoff = 3;

GetOptions(
  "src=s" => \$srccorp,
  "tgt=s" => \$tgtcorp,
  "ali=s" => \$alicorp,
  "c|cutoff=i" => \$cutoff,
) or exit 1;

my $dict = undef;

if (defined $srccorp || defined $tgtcorp || defined $alicorp 
    || ! -e $dictfile) {
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
      $dict->{$there}->{$tw}->{$sw} ++;
      $dict->{$reverse}->{$sw}->{$tw} ++;
    }
  }
  my $sline = <$srch>;
  die "$srccorp:Too long!" if defined $sline;
  my $tline = <$tgth>;
  die "$tgtcorp:Too long!" if defined $tline;

  # now save the dictionary, applying cuttoff
  my $dicth = my_save($dictfile);
  foreach my $dir ($there, $reverse) {
    foreach my $k (sort { $a cmp $b } keys %{$dict->{$dir}}) {
      foreach my $v (keys %{$dict->{$dir}->{$k}}) {
        delete $dict->{$dir}->{$k}->{$v} if $dict->{$dir}->{$k}->{$v} < $cutoff;
      }
      next if 0 == scalar keys %{$dict->{$dir}->{$k}};
      my @sorted =
        sort { $dict->{$dir}->{$k}->{$b} <=> $dict->{$dir}->{$k}->{$a} }
        keys %{$dict->{$dir}->{$k}};
      print $dicth $dir."\t".$k."\t".join(" ", @sorted)."\n"

      # now remove original counts to make the in-memory dict hold the same
      # info as the disk version does
      delete $dict->{$dir}->{$k};
      $dict->{$dir}->{$k} = \@sorted;
    }
  }
  close $dicth;
}

# load the dictionary
if (!defined $dict) {
  my $dicth = my_open($dictfile);
  while (<$dicth>) {
    chomp;
    my ($dir, $k, $vs) = split /\t/;
    my @vs = split / /, $vs;
    $dict->{$dir}->{$k} = \@vs;
  }
}

# now gloss stdin
while (<>) {
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
