#!/usr/bin/perl
# reads Czech form, lemma, tag
# produces lemmas+neg+grad+num+subpos for most words, except for:
#   pronouns: lowercased full forms
#   punctuation: lowercased full forms
#   prepositions: lowercased lemma + case
#   verbs: být, mít: lowercased full forms

use strict;
use utf8;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $nr = 0;
while (<>) {
  $nr++;
  chomp;
  my @toks = split / /;
  my @out = ();
  foreach my $tok (@toks) {
    my ($form, $lemma, $tag) = split /\|/, $tok;
    # print STDERR "$tok:  $form   $lemma    $tag\n";
    my $out;
    if ($tag =~ /^[ZP]/ || $lemma =~ /^(být|mít)($|[^[:alpha]])/) {
      $out = "F".lc($form);
    } else {
      $lemma =~ s/(.)[-;`_].*/$1/;
      $out = "L".$lemma;
    }
    push @out, $out;
  }
  my $out = join(" ", @out);
  print $out."\n";
}
