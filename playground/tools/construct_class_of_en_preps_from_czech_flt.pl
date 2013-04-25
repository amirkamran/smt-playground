#!/usr/bin/perl
# Reads form|lemma|tag created by move_info_along_ali.pl from at most 1-1 ali
#   the form|lemma|tag tokens are *Czech* but the order is actually English and
#   multiple Czech tokens can be there, concatenated by +++ (not supported here)
# Prints simplified tokens aimed at the classification of English preps and
# articles (articles for English no-prep valency)
# based on the Czech information. Note that these tokens are printed
# everywhere, not just at the positions where English target tokens occurred
# (because we do not know these positions).

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# GetOptions(
#   "help" => \$print_help,
# ) or exit 1;

my $nr = 0;
while (<>) {
  $nr++;
  chomp;
  my @intoks = split / /, trim($_);

  my @outtoks = ();
  foreach my $token_or_more (@intoks) {
    die "$nr:Unsupported +++ in: $token_or_more"
      if $token_or_more =~ /\+\+\+/;
    if ($token_or_more eq "-") {
      push @outtoks, $token_or_more;
      next;
    }
    my %tag_bag = ();
    my %lemma_bag = ();
    # foreach my $token (split /\+\+\+/, $token_or_more) {
    my $token = $token_or_more;
      my ($form, $lemma, $tag) = split /\|/, $token;
      # $tag_bag{substr($tag, 0, 1)} = 1;
      # $tag_bag{substr($tag, 0, 2)} = 1;
      $lemma =~ s/(.)[-;`_].*/$1/; # simplify the czech lemma
      # $lemma_bag{$lemma} = 1;
    # }
    my $outtok;
    if ($tag =~ /^R/) {
      $outtok = $lemma;
    } else {
      $outtok = "-";
    }
    push @outtoks, $outtok;
  }
  print join(" ", @outtoks), "\n";
}

sub trim {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
}
