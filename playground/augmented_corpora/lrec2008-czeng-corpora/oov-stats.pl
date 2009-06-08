#!/usr/bin/perl
# collect OOV stats of a test corpus given a training corpus

use strict;
use warnings;
use Getopt::Long;

# GetOptions(
# ) or exit 1;

my $trainf = shift;
die "usage!" if ! defined $trainf;

foreach my $fn (@ARGV) {
  die "Can't find $fn" if ! -e $fn;
}

my $hdl = my_open($trainf);
my $trainnl = 0;
my $trainrw = 0;
my %known = ();
while (<$hdl>) {
  $trainnl++;
  print STDERR "." if $trainnl % 100000 == 0;
  print STDERR "($trainnl)" if $trainnl % 1000000 == 0;
  chomp;
  foreach my $w (split /\s+/) {
    $known{$w} ++;
    $trainrw++;
  }
}
close $hdl;
print STDERR "Done reading $trainf.\n";

print $trainf."\tSentences\t".$trainnl."\n";
print $trainf."\tTokens\t".$trainrw."\n";
print $trainf."\tVocabulary\t".scalar(keys %known)."\n";

while (my $testf = shift) {
  my $testnl = 0;
  my $testrw = 0;
  my $testoov = 0;
  my $hdl = my_open($testf);
  while (<$hdl>) {
    $testnl++;
    chomp;
    foreach my $w (split /\s+/) {
      $testrw++;
      $testoov ++ if ! defined $known{$w};
    }
  }
  close $hdl;
  
  print "$testf\tSentences\t$testnl\n";
  print "$testf\tTokens\t$testrw\n";
  print "$testf\tOut-of-vocabulary\t$testoov\n";
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
