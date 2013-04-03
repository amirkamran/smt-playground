#!/usr/bin/perl
# Summarize the output of -translation-details of Moses

use strict;

my $sents = 0;
my $phrases = 0;
my $srcphraselen = 0;
my $tgtphraselen = 0;
while (<>) {
  $sents++ if /TRANSLATION HYPOTHESIS DETAILS/;
  if (/^\s*SOURCE: \[([0-9]+)\.\.([0-9]+\])/) {
    $phrases++;
    $srcphraselen += $2-$1 +1;
  }
  if (/^\s+TRANSLATED AS:\s*(.*)$/) {
    my $tgtphrase = $1;
    $tgtphrase =~ s/\s+$//;
    $tgtphrase =~ s/\s+/ /;
    my $cnt = $tgtphrase =~ tr/ / /;
    $cnt++; # we were counting spaces
    $tgtphraselen += $cnt;
  }
}

print "Sentences translated\t$sents\n";
print "Source words\t$srcphraselen\n";
print "Target words\t$tgtphraselen\n";
printf "Average source phrase length\t%.4f\n", $srcphraselen/$phrases;
printf "Average target phrase length\t%.4f\n", $tgtphraselen/$phrases;
printf "Average phrases per sentence\t%.4f\n", $phrases/$sents;
printf "Average source words per sentence\t%.4f\n", $srcphraselen/$sents;
printf "Average target words per sentence\t%.4f\n", $tgtphraselen/$sents;
