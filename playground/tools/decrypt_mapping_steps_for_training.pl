#!/usr/bin/perl
# This script converts the arguments to proper options of train-factored-phrase-model.perl
# The aim is to achive less typing errors when calling train-factored-phrase-model.perl
#
# Synopsis:
#  decrypt_mapping_steps_for_training.pl t0-1+t1-0+g0-1:t0,1-0,1
#  decrypt_mapping_steps_for_training.pl t0-1+t1-0+g0-1At0a1-0a1
#
#  produces:
#    --translation-factors 0-1+1-0+0,1-0,1
#    --generation-factors 0-1
#    --decoding-steps t0,t1,g0:t2
#
# You may also join all input arguments to a single argument with a + char.
#
# Ondrej Bojar.

use strict;

my @paths = split /[:A]/, join("+", @ARGV);
die "Usage:
decrypt_mapping_steps_for_training.pl t0-1+t1-0+g0-1:t0,1-0,1
The delimiters mean:
  : or A    alternative paths
  +         steps in a given path
  -         source and target factors of a step
  , or a    multiple factors used as a source or target
Use the 'a' and 'A' to avoid colons and commas on the command line.
"
  if 0 == scalar @paths;

my %cnt;
$cnt{"t"} = 0;
$cnt{"g"} = 0;
my $queue;
my @outpaths = ();
foreach my $path (@paths) {
  my @outsteps = ();
  foreach my $step (split /\+/, $path) {
    $step =~ s/a/,/g; # replacing the comma
    if ($step =~ /^([tg])([0-9,]+)-([0-9,]+)$/) {
      my $type = $1;
      my $source = $2;
      my $target = $3;
      push @{$queue->{$type}}, "$source-$target";
      push @outsteps, $type.$cnt{$type};
      $cnt{$type}++;
    } else {
      die "Malformed step: $step!";
    }
  }
  push @outpaths, join(",", @outsteps);
}

print "--translation-factors ".join("+", @{$queue->{"t"}})." " if defined $queue->{"t"};
print "--generation-factors ".join("+", @{$queue->{"g"}})." " if defined $queue->{"g"};
print "--decoding-steps ".join(":", @outpaths)."\n";

