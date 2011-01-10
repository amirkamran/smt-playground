#!/usr/bin/env perl

# USAGE: ./extract_units.pl --language=cs|en \
#                           --unit=anode|tnode|apair|tpair \ 
#                           --factors=<comma separated anode or tnode factors>
# 
# Factors can be specified by their names or positions (counted from 0).
#
# DESCRIPTION: The script takes CzEng export format as input and outputs
# anodes/tnodes/apairs/tpairs/abunches/tbunches of selected language. Used
# nodes only contain requested factors.
# * pair: node that contains parent node in the last factor positions
# * bunch: node that contains child nodes in the last factor positions
# 
# TODO: Also support output of forks
#
# Miroslav Tynovsky
#

use strict;
use warnings;
use utf8;
use Getopt::Long qw( GetOptions );
use Data::Dumper;

sub get_data {
    my ($unit, $lang, $line) = @_;
    
    # order + offset = index of line part for given lang and tree/alignment
    my %offset_of_lang = (cs => 5, en => 1);
    my %order_of_part  = (a => 0, t => 1, lexrf => 2, auxrf => 3);

    my $offset = $offset_of_lang{$lang};
    die "unknown language\n" if not defined $offset;
    my @line_parts = split /\t/, $line;

    return ($unit eq 'anode')  ? $line_parts[$order_of_part{a} + $offset]
         : ($unit eq 'tnode')  ? $line_parts[$order_of_part{t} + $offset]
         : ($unit eq 'apair')  ? $line_parts[$order_of_part{a} + $offset]
         : ($unit eq 'tpair')  ? $line_parts[$order_of_part{t} + $offset]
         : ($unit eq 'abunch') ? $line_parts[$order_of_part{a} + $offset]
         : ($unit eq 'tbunch') ? $line_parts[$order_of_part{t} + $offset]
         : die "unknown unit or not implemented\n";

}

sub get_factors {
    my ($unit, @factors) = @_;

    my @a_factors = qw( form lemma tag order gov afun );
    my @t_factors = qw( tlemma functor deepord gov nodetype formeme
                        sempos number negation tense verbmod deontmod
                        indeftype aspect numertype degcmp dispmod gender
                        iterativeness person politeness resultative
                        is_passive is_member is_clause_head is_relclause_head
                        val_frame_rf );

    my ($i, %order_of_factor);
    $i = 0; $order_of_factor{a}{$_} = $i++ for @a_factors;
    $i = 0; $order_of_factor{t}{$_} = $i++ for @t_factors;

    my $tree = substr $unit, 0, 1;
    if ($unit eq 'apair') { push @factors, 'gov' }
    if ($unit eq 'tpair') { push @factors, 'gov' }
    if ($unit eq 'abunch') { push @factors, 'gov' }
    if ($unit eq 'tbunch') { push @factors, 'gov' }

    #convert index or name of factor to index of factor
    my @factor_indexes;
    
    for my $f (@factors) { 
        my $index = $f =~ /\d+/ ? $f : $order_of_factor{$tree}->{$f};
        die "Unknown factor name: $f" if !defined($index);
        push @factor_indexes, $index;
    }

    return @factor_indexes;
}

sub node {
    my ($data, @factors) = @_;
    my @tokens = split / /, $data;
    for my $t (@tokens) {
        $t = join '|', (split /\|/, $t)[@factors];
    }
    return join ' ', @tokens;
}

sub pair {
    my ($data, @factors) = @_;
    my @tokens  = map { [ split /\|/, $_ ] } split / /, node($data, @factors);
    unshift @tokens, [ map {'-root-'} @factors]; #add technical root

    # create pairs
    my @pairs;
    for my $t (@tokens) {
        next if $t->[0] eq '-root-';
        my @gov = @{ $tokens[ $t->[-1] ] };
        push @pairs, join '|', @$t[0 .. $#factors-1], @gov[0 .. $#factors-1];
    }

    return join ' ', @pairs;
}

sub bunch {
    my ($data, @factors) = @_;
    my @tokens = map { [ split /\|/, $_ ] } split / /, node($data, @factors);
    unshift @tokens, [ map {'-root-'} @factors ]; #add technical root
    push @$_, [] for @tokens; #add arrays of children to be filled

    # attach children
    for my $t (@tokens) {
        next if $t->[0] eq '-root-';
        my $gov = $tokens[ $t->[-2] ];
        push @{$gov->[-1]}, $t;
    }
    
    # create bunches
    my @bunches;
    for my $t (@tokens) {
        last if !$t;
        my @bunch = @$t[0 .. $#factors-1];
        for my $child ( @{$t->[-1]} ) {
            push @bunch, @$child[0 .. $#factors-1];
        }
        push @bunches, join '|', @bunch;
    }

    return join ' ', @bunches;
}

#============================================================================

my %sub_for = (
    anode     => \&node,
    tnode     => \&node,
    apair     => \&pair,
    tpair     => \&pair,
    abunch    => \&bunch,
    tbunch    => \&bunch,
    tbunchset => sub {die "not implemented\n"},
    tfork     => sub {die "not implemented\n"},
    tforkset  => sub {die "not implemented\n"},
);

my ($lang, @factors, $unit);
GetOptions(
        'language=s' => \$lang,
        'factors=s'  => \@factors,
        'unit=s'     => \$unit,
);
die "mandatory parameter language not set" if !defined($lang);
die "mandatory parameter unit not set"     if !defined($unit);
die "mandatory parameter factors not set"  if !@factors;


@factors = split /,/, join(',', @factors); # allow multiple appearances with 
                                           # multiple comma separated values

while (<>) {
    print $sub_for{$unit}->( get_data($unit, $lang, $_), 
                             get_factors($unit, @factors) ), "\n";
}

