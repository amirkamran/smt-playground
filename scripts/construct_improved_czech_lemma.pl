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
      $out = substr($tag, 1, 1).".".lc($form);
    } elsif ($tag =~ /^R...(.)/) {
      my $case = $1;
      $lemma =~ s/(.)[-;`_].*/$1/;
      $out = $lemma."+$case";
    } else {
      my $subposneggradnum = substr($tag, 1, 1).substr($tag, 3, 1)
                      .substr($tag, 10, 1).substr($tag, 9, 1);
      $lemma =~ s/(.)[-;`_].*/$1/;
      $out = $subposneggradnum.".".$lemma;
    }
    push @out, $out;
  }
  my $out = join(" ", @out);
  print $out."\n";
}
