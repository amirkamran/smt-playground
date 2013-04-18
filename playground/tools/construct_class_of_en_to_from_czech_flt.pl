#!/usr/bin/perl
# Reads form|lemma|tag+++form|lemma|tag created by move_info_along_ali.pl
#   the form|lemma|tag are *Czech* but the order is actually English and
#   multiple Czech tokens can be there, concatenated by +++
# Prints simplified tokens aimed at the classification of the English 'to'
# based on the Czech information. Note that these tokens are printed
# everywhere, not just at the positions where the English 'to' occurred
# (because we do not know these positions).

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# GetOptions(
#   "help" => \$print_help,
# ) or exit 1;

my @preferred_lemmas = qw(
a¾  aby
na k do se pro s podle muset chtít uvedený o mít který v ¾e být ten za
øízení moci sna¾it cíl zaèít obì» pøi a rád u
);

my @preferred_tags = qw(
Vf
V N A 
R
J D
);

my @preferred_lemmas = qw(a¾  aby)

my $nr = 0;
while (<>) {
  $nr++;
  chomp;
  my @intoks = split / /, trim($_);

  my @outtoks = ();
  foreach my $token_or_more (@intoks) {
    if ($token_or_more eq "-") {
      push @outtoks, $token_or_more;
      next;
    }
    my %tag_bag = ();
    my %lemma_bag = ();
    foreach my $token (split /\+\+\+/, $token_or_more) {
      my ($form, $lemma, $tag) = split /\|/, $token;
      $tag_bag{substr($tag, 0, 1)} = 1;
      $tag_bag{substr($tag, 0, 2)} = 1;
      $lemma =~ s/(.)[-;`_].*/$1/; # simplify the czech lemma
      $lemma_bag{$lemma} = 1;
    }
    my $outtok = undef;
    foreach my $lemma (@preferred_lemmas) {
      if (defined $lemma_bag{$lemma}) {
        $outtok = "L".$lemma;
        last;
      }
    }
    if (!defined $outtok) {
      foreach my $tag (@preferred_tags) {
        if (defined $tag_bag{$tag}) {
          $outtok = $tag;
          last;
        }
      }
    }
    $outtok = "oth" if !defined $outtok;
    push @outtoks, $outtok;
  }
  print join(" ", map { $_ // "-" } @outtoks), "\n";
}

sub trim {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
}
