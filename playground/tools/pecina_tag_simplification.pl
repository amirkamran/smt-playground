#!/usr/bin/perl -w

use strict;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $map_file = $ARGV[0];
my %map_hash;
my ($key, $val);
my @val_array;

die "No map file specified\n" if (not defined $map_file);

open(MAP, $map_file) || die "Can't open $map_file";

my $n = 0;
while (<MAP>) {
  chomp;
  ($key, $val) = split;
  @val_array = split (//, $val);
  die "Error while loading mapping: $key\n" if (scalar @val_array != 15);
  for (my $i = 0; $i < scalar @val_array; $i++) {
    $map_hash{$key}[$i] = $val_array[$i];
  }
  $n++;
}
print STDERR "Loaded mappings: $n\n";
close (MAP);

my $line;
my @array;
my @tag_array;
my ($form,$lemma,$tag,$pos);

$n = 0;
my $all = 0;
while (<STDIN>) {
  chomp;
  @array = split;
  for (my $i = 0; $i < scalar @array; $i++) {
    ($form,$lemma,$tag) = split (/\|/, $array[$i]);
    $lemma =~ s/[_\`].*$//;
    $lemma =~ s/-[0-9]+$//;
    @tag_array = split (//, $tag);
    $pos = $tag_array[0];
    if (defined $map_hash{$pos}) {
      for (my $j = 0; $j < scalar @tag_array; $j++ ){
        $tag_array[$j] = "_" if ($map_hash{$pos}[$j] eq '_');
      }
      $n++;
    }
    $all++;
    $tag = join ("", @tag_array);
    $array[$i] = $lemma."|".$tag;
#   $array[$i] = $tag;
  }
  $line = join(" ", @array);
  print $line."\n";
}

printf STDERR "Modified tokens: %d/%d (%.2f%%)\n", $n, $all, ($n/$all*100);
