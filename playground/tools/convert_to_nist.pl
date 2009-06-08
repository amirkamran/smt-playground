#!/usr/bin/perl
# expects several files.hyp as args, produces one output, each of the file will
# be considered a separate 'system', sysid will point to the file
#
# OUTDATED, use wrapmteval.pl instead

use strict;
use Getopt::Long;

my $untokenize = 0;
my $srclang = "SRCLANG";
my $trglang = "TGTLANG";
my $setid = "SETID";
my $docid = "DOCID";
my $type = "tstset";

GetOptions(
  "untokenize"=>\$untokenize,
  "srclang=s" => \$srclang,
  "trglang=s" => \$trglang,
  "setid=s" => \$setid,
  "docid=s" => \$docid,
  "type=s" => \$type,
) or exit 1;

die "Bad type: $type"
  if $type ne "refset" && $type ne "tstset" && $type ne "srcset";

# hardwired token lists for untokenization
# see sub untokenize below
my $nospacebef = "'s n't \\. , '' -- % \\) :";
$nospacebef =~ s/ /\|/g;
my $nospaceaft = "`` -- \\( \\\$";
$nospaceaft =~ s/ /\|/g;


print "<$type setid=\"$setid\" srclang=\"$srclang\" trglang=\"$trglang\">\n";

my $expnr = undef;
while (my $fn = shift) {
  print "<DOC docid=\"$docid\" sysid=\"$fn\">\n";

  open INF, $fn or die "Can't read $fn";
  my $nr = 0;
  while (<INF>) {
    $nr++;
    chomp;
    $_ =~ s/^\s+|\s+$//g;
    $_ =~ s/\s+/ /g;
    $_ = untokenize($_) if $untokenize;
    print "<seg id=\"$nr\">$_</seg>\n";
  }
  close INF;
  die "$fn: wrong number of sentences. Got $nr, expected $expnr\n"
    if defined $expnr && $nr != $expnr;
  $expnr = $nr;
  
  print "</DOC>\n";
}

print "</$type>\n";

sub untokenize {
  my $s = shift;

  $s =~ s/-LRB-/(/g;
  $s =~ s/-RRB-/)/g;
  $s =~ s/\s+($nospacebef)/$1/g;
  $s =~ s/($nospaceaft)\s+/$1/g;
  return $s;
}
