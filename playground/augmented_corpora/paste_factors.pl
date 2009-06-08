#!/usr/bin/perl
# Modify stdin->stdout by appending factors from all files specified at the
# command line after the factors in the given column.

use strict;
use Getopt::Long;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $col = 0;
GetOptions(
  "col=i" => \$col,
) or exit 1;


my @streams = map {
  my $stream = my_open($_);
  die "Can't read '$_'" if !defined $stream;
  { "hdl" => $stream, "fname" => $_ };
} @ARGV;
@ARGV = (); # we consumed all the args

my $nl = 0;
while (<>) {
  $nl++;
  print STDERR "." if $nl % 10000 == 0;
  print STDERR "($nl)" if $nl % 100000 == 0;
  chomp;
  my @cols = split /\t/;
  die "$nl: Missed column $col in: $_"
    if !defined $cols[$col];
  my @toks = split / /, $cols[$col];

  foreach (@streams) {
    my $l = readline($_->{"hdl"});
    die "$nl:File $_->{fname} too short!" if !defined $l;
    chomp $l;
    my @t = split / /, $l;
    die "$nl:Mismatched token count in file $_->{fname}, got "
      .scalar(@t)." expected ".scalar(@toks)
      if scalar(@t) != scalar(@toks);
    for(my $i=0; $i<@toks; $i++) {
      $toks[$i] .= "|$t[$i]";
    }
  } @streams;

  $cols[$col] = join(" ", @toks);
  print join("\t", @cols)."\n";
}
print STDERR "Done.\n";


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
