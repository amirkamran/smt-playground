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
  $map_hash{$key} = $val;
  $n++;
}
print STDERR "Loaded mappings: $n\n";
close (MAP);

my $line;
my @array;
my ($form, $lemma, $tag);

my $mod = 0;
my $all = 0;
while (<STDIN>) {
  chomp;
  @array = split;
  for (my $i = 0; $i < scalar @array; $i++) {
    ($form,$lemma,$tag) = split (/\|/, $array[$i]);
    $lemma =~ s/[_\`].*$//;
    $lemma =~ s/-[0-9]+$//;
    $tag =~ s/...$//;
    if (defined $map_hash{$tag}) {
      $tag = $map_hash{$tag};
      $mod++;
    } else {
      # print $tag."\n";
    }
    $array[$i] = $form."|".$lemma."|".$tag;
    $all++;
  }
  $line = join(" ", @array);
  print $line."\n";
}

printf STDERR "Modified tokens: %d/%d (%.2f%%)\n", $mod, $all, ($mod/$all*100);
