#!/usr/bin/perl
# given a factored input produces four output factors: subpos|case|number|gender

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $infactor = 0; # assume the tag is in the first (only) input factor
my $ttable = undef; # process ttable: src or tgt
my $preserve_other_factors = 0;
  # just replace the tag factor; should be used whenever --ttable is set
GetOptions(
  "factor=i" => \$infactor,
  "ttable=s" => \$ttable,
  "preserve-other-factors" => \$preserve_other_factors,
) or exit 1;

my $ttablecol = undef;
if (defined $ttable) {
  if ($ttable eq "src") {
    $ttablecol = 0;
  } elsif ($ttable eq "tgt") {
    $ttablecol = 1;
  } else {
    die "Bad ttable side specification: $ttable"
  }
}

my $nr=0;
while (<>) {
  $nr++;
  print STDERR "." if $nr % 10000 == 0;
  print STDERR "($nr)" if $nr % 100000 == 0;
  chomp;
  my $outline = shift;
  if (defined $ttablecol) {
    my @cols = split /\|\|\|/, $_;
    my $outcol = convert_line($cols[$ttablecol]);
    $cols[$ttablecol] = " ".$outcol." ";
    $outline = join("|||", @cols);
  } else {
    $outline = convert_line($_);
  }
  print $outline, "\n";
}
print STDERR "Done.\n";

sub convert_line {
  my $line = shift;
  $line =~ s/^ +//;
  $line =~ s/ +$//;
  my @out = ();
  foreach my $token (split / /, $line) {
    my @factors = split /\|/, $token;
    my $fact = @factors[$infactor];
    if ($fact =~ /^(..)(.)(.)(.)/) {
      my $outfact = "$1|$4|$3|$2";
      my $outtoken = undef;
      if ($preserve_other_factors) {
        $factors[$infactor] = $outfact;
        $outtoken = join("|", @factors);
      } else {
        $outtoken = $outfact;
      }
      push @out, $outtoken;
    } else {
      die "$nr: $token: Tag too short!"
    }
  }
  return join(" ", @out);
}
