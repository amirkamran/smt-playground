#!/usr/bin/perl
# given a factored input produces a single-factor file
# cuts off last --cut=N letters from each word

use strict;
use Getopt::Long;
use List::Util qw(min max);

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $infactor = 0; # assume the tag is in the first (only) input factor
my $cut = 3;
my $minstem = 3;
my $from_beginning = 0; 
GetOptions(
  "factor=i" => \$infactor,
  "cut=i" => \$cut,
  "minstem=i" => \$minstem,
  "from-beginning" => \$from_beginning
) or exit 1;

my $nr=0;
while (<>) {
  $nr++;
  print STDERR "." if $nr % 10000 == 0;
  print STDERR "($nr)" if $nr % 100000 == 0;
  chomp;
  my @out = ();
  foreach my $token (split / /) {
    my @factors = split /\|/, $token;
    my $fact = @factors[$infactor];
    my $cut_actual = max(0, min($cut, length($fact) - $minstem));
    my $beg = $from_beginning ? $cut_actual : 0;
    my $len = length($fact) - $cut_actual;
    push @out, substr($fact, $beg, $len);
  }
  print join(" ", @out)."\n";
}
print STDERR "Done.\n";

