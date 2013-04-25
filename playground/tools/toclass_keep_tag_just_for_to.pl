#!/usr/bin/perl
# an auxiliary script for toclass: given stc|toclass sets toclass to "-" if the
# stc is anything else than 'to'.
# This is useful for creating the training corpus, where toclass is 100%
# correct wrt target side but where other tokens are not diluted.

while (<>) {
  chomp;
  my @line = split / /;
  for(my $i; $i<@line; $i++) {
    my ($stc, $toclass) = split /\|/, $line[$i];
    print " " if $i>0;
    print $stc, "|";
    if ($stc eq "to") {
      print $toclass;
    } else {
      print "-";
    }
  }
  print "\n";
}
