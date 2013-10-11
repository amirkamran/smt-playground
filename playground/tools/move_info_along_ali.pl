#!/usr/bin/perl
# Reads: src sent \t tgt sent \t alignment (src-tgt)
# prints tgt-many tokens, each either - (if no alignment was mentioning it)
# or ("+++"-joined) values from the ali-linked src tokens

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# GetOptions(
#   "help" => \$print_help,
# ) or exit 1;

my $nr = 0;
while (<>) {
  $nr++;
  chomp;
  my ($src, $tgt, $alistr) = split /\t/;
  my @src = split / /, trim($src);
  my @tgt = split / /, trim($tgt);

  my @outtoks = map { undef } @tgt;
  foreach my $pair (split(/ /, trim($alistr))) {
    my ($a, $b) = split /-/, $pair;
    die "$nr:Bad alignment point $pair: out of source sent" if $a > $#src;
    die "$nr:Bad alignment point $pair: out of target sent" if $b > $#tgt;
    if (defined $outtoks[$b]){
      $outtoks[$b] .= "+++".$src[$a];
    } else {
      $outtoks[$b] = $src[$a];
    }
  }
  print join(" ", map { $_ // "-" } @outtoks), "\n";
}

sub trim {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
}
