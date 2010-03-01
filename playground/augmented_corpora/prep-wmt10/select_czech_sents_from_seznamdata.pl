#!/usr/bin/perl
# selects Czech sentences from seznamdata using quick heuristics.

use utf8;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# seznamdata is here:
# ~bojar/diplomka/seznam/data.gz

my %dict;
{ # Czech dict
my $dictf = "/export/projects/tectomt_shared/resource_data/czech_wordforms_from_syn.txt.gz";
print STDERR "Loading dictionary for cs: $dictf\n";
my $dicth = my_open($dictf);
while (<$dicth>) {
  chomp;
  my ($cnt, $word) = split /\t/;
  next if $cnt < 2; # require at least two occs
  foreach my $w (split /\b/, $word) { # resplit words
    next if $w !~ /^[[:alpha:]]+$/;
    my $lc = lc($w); # lowercasing
    $dict{$lc} = 1;
  }
}
close $dicth;
}

my $no = 0; # output sents
my $nr = 0;
while (<>) {
  $nr++;
  print STDERR "." if $nr % 10000 == 0;
  print STDERR "(in:$nr, out:$no)" if $nr % 100000 == 0;
  print STDERR "\n" if $nr % 1000000 == 0;
  chomp;
  s/^.*\t//; # drop all columns
  s/»••»/\n/g;
  while (/(^|(?<=[.!?]\s))[[:punct:]]?[[:upper:]][[:alpha:]]*(\s+[[:alpha:][:digit:][:punct:]]+){5,150}?[.?!](?=\s[[:upper:]])/g) {
  # while (/(^|(?<=[.!?]\s))[[:punct:]]?[[:upper:]][[:alpha:]]*(\s+([[:alpha:]]+\.?|[-[:digit:],.]+)|[[:punct:]]){5,150}?[.?!](?=\s[[:upper:]])/g) {
    my $sents = $&;
    next if $sents !~ /[ĚŠČŘŽÝÁÍÉÚŮěščřžýáíéúů]/;
    while ($sents =~ /[[:punct:]]?[[:upper:]].*?[.?!](?=\s[[:upper:]])/g) {
      my $sent = $&;
      next if $sent !~ /[ĚŠČŘŽÝÁÍÉÚŮěščřžýáíéúů]/;
      my $totwords = 0;
      while ($sent =~ /[[:alpha:]]+/g) {
        my $word = $&;
        $totwords ++;
        $okwords ++ if $dict{lc($word)};
      }
      next if $okwords / $totwords * 100 < 50; # require 50 % valid words
      print $sent."\n";
      $no++;
    }
  }
}
print STDERR "Done.\n";

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
