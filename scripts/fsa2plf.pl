#!/usr/bin/perl
# Converts AT&T FSA format to 'python lattice format'.
# Note that the input FSA needs to be epsilon-free and topologically sorted.
# This script checks for topological sortedness.
# The start node has to have the index 0.
# All path ends are assumed to be final nodes, not just the explicitly stated
# final nodes.
# Ondrej Bojar, bojar@ufal.mff.cuni.cz

use strict;

# not necessary until we touch tokens' contents
# binmode(STDIN, ":utf8");
# binmode(STDOUT, ":utf8");
# binmode(STDERR, ":utf8");

my @outnodes = ();
my $nr = 0;
while (<>) {
  chomp;
  $nr++;
  my ($src, $tgt, $label, $weight) = split /\s+/;
  die "$nr:Bad src node index: $src" if $src !~ /^[0-9]+$/;
  if (!defined $tgt) {
    # explicit final node
    $is_final{$src};
    next;
  }
  XXX
}
