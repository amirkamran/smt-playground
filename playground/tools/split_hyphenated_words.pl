#!/usr/bin/perl
# splits hyphenated words in stdin, splitting the first factor and exploding
# the remaining factors

use strict;
use File::Path;
use File::Basename;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");


my $split_factors = "0,1";
my $inalif = undef;
GetOptions(
  "inali=s" => \$inalif,
) or exit 1;


my $inalih;
my $outalih;
if (defined $inalif) {
  $inalih = my_open($inalif);
  $outalih = my_save(dirname($inalif)."/split-".basename($inalif));
}

my $expanded_toks = 0;
my $nr = 0;
while (<>) {
  $nr++;
  print STDERR "." if $nr % 100000 == 0;
  print STDERR "($nr)" if $nr % 1000000 == 0;
  chomp;
  my @toks = split / /;
  my @shift = ();
  my @expand = ();
  my @outtoks = ();
  foreach my $i (0..$#toks) {
    if ($toks[$i] =~ /^[^|]*-[^|]+/) {
      # need to handle the token
      $expanded_toks++;
      my @facts = split /\|/, $toks[$i];
      my @parts = split /(-)/, $facts[0];
      foreach my $part (@parts) {
        push @outtoks, join("|", ($part, @facts[1..$#facts]));
      }
      $expand[$i] = scalar @parts; # will have to replicate alignment links
      foreach my $j (($i+1)..$#toks) {
        $shift[$j] += scalar(@parts)-1;
      }
    } else {
      push @outtoks, $toks[$i];
    }
  }
  print join(" ", @outtoks)."\n";
  # shift and explode alignments, as necessary
  if (defined $inalih) {
    my $ali = <$inalih>;
    chomp $ali;
    my @outpairs = ();
    foreach my $pair (split / /, $ali) {
      my ($a, $b) = split /-/, $pair;
      my $newa = $a+$shift[$a];
      my $expand = $expand[$a];
      $expand = 1 if !defined $expand;
      # print "EXPAND $a (newly $newa) to $expand tokens\n";
      foreach my $i (1..$expand) {
        push @outpairs, ($newa+$i-1)."-$b";
      }
    }
    print $outalih join(" ", @outpairs)."\n";
  }
}
print STDERR "Done.\n";
print STDERR "Expanded $expanded_toks tokens.\n";

if (defined $inalih) {
  close($inalih);
  close($outalih);
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
    $opn = "| gzip -c > '$f'";
  } elsif ($f =~ /\.bz2$/) {
    $opn = "| bzip2 > '$f'";
  } else {
    $opn = ">$f";
  }
  mkpath( dirname($f) );
  open $hdl, $opn or die "Can't write to '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}
