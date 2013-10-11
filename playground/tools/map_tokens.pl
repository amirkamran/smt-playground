#!/usr/bin/perl -w
# use a given map file to map every token, if there is a replacement

use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $map_file = shift;
my %map_hash;

die "No map file specified\n" if (not defined $map_file);

my $n = 0;
my $h = my_open($map_file);
while (<$h>) {
  chomp;
  my ($key, $val) = split /\t/;
  die "Duplicated value for '$key': '$val' vs. '$map_hash{$key}'"
    if defined $map_hash{$key};
  die "Space in key: '$key'" if $key =~ /\s/;
  die "Space in val: '$val'" if $val =~ /\s/;
  $map_hash{$key} = $val;
  $n++;
}
print STDERR "Loaded mappings: $n\n";
close($h);

my $mod = 0;
my $all = 0;
while (<>) {
  chomp;
  my @array = split / /;
  for (my $i = 0; $i < scalar @array; $i++) {
    my $known = $map_hash{$array[$i]};
    if (defined $known) {
      $array[$i] = $known;
      $mod++;
    }
    $all++;
  }
  print join(" ", @array), "\n";
}

printf STDERR "Modified tokens: %d/%d (%.2f%%)\n", $mod, $all, ($mod/$all*100);

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
