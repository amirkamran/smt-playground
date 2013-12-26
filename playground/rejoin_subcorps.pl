#!/usr/bin/perl
# usage: ./rejoin_subcorps.pl INCORP SPLITSPEC INAUG tokenfile token1:INLANG1 token2:INLANG2
# given a file where each line holds a distinguisting token, it collects and merges all the splits
# relies on corpman INCORP/INLANGx+INAUG
# emits the joined corpus
# dies if some token was not seen

use strict;
use FileHandle;
use Getopt::Long;
my $corpman = "../corpman";

GetOptions(
  "corpman=s" => \$corpman,
) or exit 1;

my $incorp = shift;
my $splitspec = shift;
my $inaug = shift;
my $tokenfile = shift;
my @toksources = @ARGV;

die "usage: $0 INCORP SPLITSPEC INAUG tokenfile token1:INLANG1 token2:INLANG2"
  if ! defined $tokenfile;

my %sources;
foreach my $toksource (@toksources) {
  my ($token, $inlang) = split /:/, $toksource, 2;
  die "Duplicated source for token '$token'"
    if defined $sources{$token};
  $sources{$token} = FileHandle->new("$corpman -dump $incorp-$splitspec-$token/$inlang+$inaug |");
}

my $inh = my_open($tokenfile);
while (<$inh>) {
  chomp;
  my $token = $_;
  die "Unknown token: $token" if !defined $sources{$token};
  my $outline = $sources{$token}->getline;
  die "Source for $token too short!" if !defined $outline;
  chomp $outline;
  print $outline, "\n";
}
foreach my $token (keys %sources) {
  my $outline = $sources{$token}->getline;
  die "Source for token $token too long!" if defined $outline;
  close $sources{$token};
}
close $inh;


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
