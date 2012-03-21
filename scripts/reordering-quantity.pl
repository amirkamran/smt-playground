#!/usr/bin/perl

# Compute reordering quantity from word alignment in Giza++ format.
# If verbose (-v), also print RQuantity of each sentence.
# (for reference, see Birch et al.: Predicting Success in Machine Translation)

use strict;
use warnings;
use List::Util qw( min max );

my $linecount = 0;
my $tot_rquantity = 0;
my $verbose = 0;

$verbose = 1 if defined $ARGV[0] && $ARGV[0] eq '-v';

while (<STDIN>) {
  chomp;
  my @points = split ' ', $_;

  $linecount++;

  ## load alignment points into hashes
  my %src2tgt;
  my %tgt2src;

  my $source_length = 0;
  for my $point (@points) {
    my ($src, $tgt) = split "-", $point;
    $source_length = max($source_length, $src + 1);
    push @{ $src2tgt{$src} }, $tgt;
    push @{ $tgt2src{$tgt} }, $src;
  }

  ## extract all reorderings
  my $reordered_spans_length = 0;

  # over all words
  for (my $i = 1; $i < $source_length; $i++) { 

    # initial A, B of length 1
    my ($a_begin, $a_length, $b_begin, $b_length) = ($i - 1, 1, $i, 1);
    my ($a_begin_opp, $a_length_opp) = get_opposite_span(\%src2tgt, $a_begin, $a_length);
    my ($b_begin_opp, $b_length_opp) = get_opposite_span(\%src2tgt, $b_begin, $b_length);

    # A or B are not aligned to anything
    next if ! defined($a_begin_opp) || ! defined($b_begin_opp);

    next if $a_begin_opp <= $b_begin_opp + $b_length_opp; # no reordering

    # grow block A to the left
    #   
    # XXX this is not exactly described in the paper
    # the most "likely" correct solution is implemented here, i.e.:
    #   - allow A to grow to the first consistent span
    #   - after that, each extension of A must be consistent

    while ($a_begin > 0) { 
      if (is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length)) { 
        last if ! is_consistent_span(\%src2tgt, \%tgt2src, $a_begin - 1, $a_length + 1);
      }   
      my ($a_ext_begin_opp, $a_ext_length_opp) = 
        get_opposite_span(\%src2tgt, $a_begin - 1, $a_length + 1); 
      if ($a_ext_begin_opp > $b_begin_opp + $b_length_opp) { 
        $a_begin--;
        $a_length++;
        $a_begin_opp = $a_ext_begin_opp;
        $a_length_opp = $a_ext_length_opp;
      } else {
        last;
      }   
    }   

    # never reached a consistent block A
    next if ! is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length);

    # grow B to the right
    while ($b_begin + $b_length < $source_length) { 
      last if is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length + $b_length);
      my ($b_ext_begin_opp, $b_ext_length_opp) = 
        get_opposite_span(\%src2tgt, $b_begin, $b_length + 1); 
      if ($a_length_opp > $b_ext_begin_opp + $b_ext_length_opp) { 
        $b_length++;
        $b_begin_opp = $b_ext_begin_opp;
        $b_length_opp = $b_ext_length_opp;
      } else {
        last;
      }   
    }      
    
    # never reached a consistent block AB
    next if ! is_consistent_span(\%src2tgt, \%tgt2src, $a_begin, $a_length + $b_length);

    $reordered_spans_length += $a_length + $b_length;
  }   

  ## compute the RQuantity
  my $rquantity = $reordered_spans_length / $source_length;
  printf "%.02f\n", $rquantity if $verbose;
  $tot_rquantity += $rquantity;
}

printf "%.02f (%d / %d)\n", $tot_rquantity / $linecount, $tot_rquantity, $linecount;
 
# given a source block, return the span of its links on the target side
sub get_opposite_span {
  my ($links, $begin, $length) = @_; 
    
  my %points_to;

  for (my $i = $begin; $i != $begin + $length; $i++) {
    next if ! $links->{$i};
    map { $points_to{$_} = 1 } @{ $links->{$i} };
  }

  return undef if ! keys %points_to;

  my $opposite_begin = min(keys %points_to);
  my $opposite_length = max(keys %points_to) - $opposite_begin;

  return ($opposite_begin, $opposite_length);
}

# check span consistency (i.e. no target words are aligned outside source span)
sub is_consistent_span {
  my ($src2tgt, $tgt2src, $begin, $length) = @_;

  my ($opposite_begin, $opposite_length) = get_opposite_span($src2tgt, $begin, $length);

  for (my $i = $opposite_begin; $i != $opposite_begin + $opposite_length; $i++) {
    my $has_link_outside = grep {
      $_ < $begin || $_ >= $begin + $length
    } @{ $tgt2src->{$i} };
    return 0 if $has_link_outside;
  }

  return 1;
}
