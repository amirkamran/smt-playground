#!/usr/bin/perl
# Prints only sentences with nice words.

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $col = 0;
my $fact = 0;
my $dictfn = undef;
GetOptions(
  "col=i" => \$col, # consider only this column (default 0)
  "fact=i" => \$fact, # consider this factor (default 0)
  "dict=s" => \$dictfn, # load dictionary of valid words from here
) or exit 1;

my %dict;
if (defined $dictfn) {
  print STDERR "Loading $dictfn...\n"; 
  my $hdl = my_open($dictfn);
  while (<$hdl>) {
    chomp;
    $dict{$_}=1;
    $dict{lc($_)}=1;
  }
  close $hdl;
  print STDERR "Loaded $dictfn.\n"; 
}

my %valid_wt = map { ($_, 1) } qw/punct num name dict lcdict other/;

my $nr = 0;
my $kept = 0;
my @totlengths = ();
my $totwts;
my $totwc = 0;
SENT: while (<>) {
  $nr++;
  print STDERR "." if $nr % 100000 == 0;
  print STDERR "$nr" if $nr % 1000000 == 0;
  my $line = $_;
  chomp $line;
  my @cols = split /\t/, $line;
  my @words = split / /, $cols[$col];

  my $wc = scalar @words;
  my $allow_invalid = $wc * 15/100;
  my $invalid = 0;
  my %wts = ();
  foreach my $w (@words) {
    my @facts = split /\|/, $w;
    my $f = $facts[$fact];
    die "$nr:Failed to read factor $fact of '$w' in $line"
      if !defined $f;
    my $wt = word_type($f);
    die "Unknown word type: $wt" if !defined $valid_wt{$wt};
    $invalid += ($wt eq "other");
    next SENT if $invalid > $allow_invalid;
    $wts{$wt}++;
  }

  $kept ++;

  # collect statistics from passing sentences
  $totwc += $wc;
  push @totlengths, $wc;
  foreach my $wt (keys %valid_wt) {
    $wts{$wt} = 0 if !defined $wts{$wt};
    push @{$totwts->{$wt}}, $wts{$wt}/$wc*100;
  }
  print join(" ", %wts), "\t", $line, "\n";
}
print STDERR "Done, kept $kept sents out of $nr\n";

# print overall statistics
print STDERR "Sentence length: ".arrayinfo(\@totlengths).", macro-avg: "
  .sprintf("%.2f", $totwc/$kept)."\n";
foreach my $wt (sort keys %valid_wt) {
  print STDERR "Word type $wt: ".arrayinfo($totwts->{$wt})."\n";
}

sub arrayinfo {
  my $arr = shift;
  my $sum = 0;
  my $min = undef;
  my $max = undef;
  foreach my $x (@$arr) {
    $min = $x if !defined $min || $min > $x;
    $max = $x if !defined $max || $max < $x;
    $sum += $x;
  }
  my $cnt = scalar @$arr;
  return "-" if $cnt == 0;
  return sprintf("%i/%.2f/%i", $min, ($sum/$cnt), $max);
}

sub word_type {
  my $w = shift;

  return "punct" if $w =~ /^[[:punct:]]+$/o;
  return "num" if $w =~ /^[-.,0-9]+$/o;
  return "name" if $w =~ /^\p{Lu}+(\p{M}|\p{L})*$/o;
  return "dict" if $dict{$w};
  return "lcdict" if $dict{lc($w)};
  return "other";
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
