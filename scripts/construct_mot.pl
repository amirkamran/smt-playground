#!/usr/bin/perl
# reads Czech form, lemma, tag
# produces lemmas+neg+grad+num+subpos for most words, except for:
#   pronouns: lowercased full forms
#   punctuation: lowercased full forms
#   prepositions: lowercased lemma + case
#   verbs: být, mít: lowercased full forms

use strict;
use utf8;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $scheme = 0; 

GetOptions(
  "scheme=s" => \$scheme,
) or exit 1;

my %schemes;


foreach my $s (split('\|', $scheme)) {
  my ($startsWith, $index) = split('\-',$s);
  $schemes{$startsWith} = $index;
}

my $nr = 0;
while (<>) {
  $nr++;
  chomp;
  my @toks = split / /;
  my @out = ();
  foreach my $tag (@toks) {
    # print STDERR "$tok: $tag\n";
    my $out;
    my $pos = substr($tag, 0, 1);
    my $indices = $schemes{$pos};
    if(!defined($indices)) {
        $indices = $schemes{'*'};
    }
    
    foreach my $index (split(',', $indices)) {
	$out = $out.substr($tag, $index, 1);
    }

    push @out, $out;
  }
  my $out = join(" ", @out);
  print $out."\n";
}
