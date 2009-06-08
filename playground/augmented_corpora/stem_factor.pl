#!/usr/bin/perl
# given a factored input produces a single-factor file
# chops off first --stem=N characters

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $infactor = 0; # assume the tag is in the first (only) input factor
my $stem = 4;
GetOptions(
  "factor=i" => \$infactor,
  "stem=i" => \$stem,
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
    push @out, substr($fact, 0, $stem);
  }
  print join(" ", @out)."\n";
}
print STDERR "Done.\n";

