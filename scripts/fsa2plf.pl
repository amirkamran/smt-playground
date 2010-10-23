#!/usr/bin/perl
# Converts AT&T FSA format to 'python lattice format'.
# Note that the input FSA needs to be epsilon-free and topologically sorted.
# This script checks for topological sortedness.
# The start node has to have the index 0.
# All path ends are assumed to be final nodes, not just the explicitly stated
# final nodes.
# Note that the output format may not contain any spaces.
# Ondrej Bojar, bojar@ufal.mff.cuni.cz

use strict;

# not necessary until we touch tokens' contents
# binmode(STDIN, ":utf8");
# binmode(STDOUT, ":utf8");
# binmode(STDERR, ":utf8");

my @outnodes = ();
my %is_final; # remember which nodes were final
my $nr = 0;
while (<>) {
  chomp;
  $nr++;
  my ($src, $tgt, $label, $weight) = split /\s+/;
  die "$nr:Bad src node index: $src" if $src !~ /^[0-9]+$/;
  if (!defined $tgt) {
    # explicit final node, warn at the end if there are any intermed. final
    # nodes
    $is_final{$src};
    next;
  }
  # remember the node
  push @{$outnodes[$src]}, [ $label, $weight, $tgt-$src ];
}

my $err = 0;
foreach my $f (keys %is_final) {
  if (defined $outnodes[$f]) {
    print STDERR "Node $f is final by has outgoing edges!\n";
    $err = 1;
  }
}
exit 1 if $err;

print "(";
foreach my $outnode (@outnodes) {
  print "(";
  foreach my $arc (@$outnode) {
    print "('".apo($arc->[0])."',$arc->[1],$arc->[2]),";
  }
  print "),";
}
print ")\n";

sub apo {
  my $s = shift;
  # protects apostrophy and backslash
  $s =~ s/\\/\\\\/g;
  $s =~ s/[']/\\$1/g;
  return $s;
}
