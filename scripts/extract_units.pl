#!/usr/bin/env perl

# USAGE: ./extract_units.pl --language=cs|en \
#                           --unit=anode|tnode|apair|tpair|abunch|tbunch \ 
#                           --factors=<comma separated anode or tnode factors>
#                           --gov-factors=<factors of gov if different>
# 
# Factors can be specified by their names or positions (counted from 0).
#
# DESCRIPTION: The script takes CzEng export format as input and outputs
# anodes/tnodes/apairs/tpairs/abunches/tbunches of selected language. Used
# nodes only contain requested factors.
# * pair: node that contains parent node in the last factor positions
# * bunch: node that contains child nodes in the last factor positions
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

    return \@factor_indexes;
}

sub node {
    my ($data, $factors, undef) = @_; #intentionally ignore third argument
    my @tokens = split / /, $data;
    for my $t (@tokens) {
        $t = join '|', (split /\|/, $t)[@$factors];
    }
    return join ' ', @tokens;
}

sub pair {
    my ($data, $factors, $gov_factors) = @_;
    my @tokens     = map { [ split /\|/, $_ ] }
                        split / /, node($data, $factors);
    my @gov_tokens = map { [ split /\|/, $_ ] }
                        split / /, node($data, $gov_factors);
    unshift @gov_tokens, [ map {'-root-'} @$gov_factors]; #add technical root

    # create pairs
    my $last_factor = scalar(@$factors) - 2; #omit technical gov
    my $last_gov = scalar(@$gov_factors) - 2;
    my @pairs;
    for my $t (@tokens) {
        my @gov = @{ $gov_tokens[ $t->[-1] ] };
        push @pairs, join '|', @$t[0 .. $last_factor], @gov[0 .. $last_gov];
    }

    return join ' ', @pairs;
}

sub bunch {
    my ($data, $factors, $gov_factors) = @_;
    my @tokens     = map { [ split /\|/, $_ ] }
                        split / /, node($data, $factors);
    my @gov_tokens = map { [ split /\|/, $_ ] }
                        split / /, node($data, $gov_factors);

    unshift @gov_tokens, [ map {'-root-'} @$gov_factors ]; #add technical root
    push @$_, [] for @gov_tokens; #add arrays of children to be filled

    # attach children
    for my $t (@tokens) {
        next if $t->[0] eq '-root-';
        my $gov = $gov_tokens[ $t->[-2] ];
        push @{$gov->[-1]}, $t;
    }
    
    # create bunches
    my $last_factor = scalar(@$factors) - 2; #omit technical gov
    my $last_gov = scalar(@$gov_factors) - 2;
    my @bunches;
    for my $t (@gov_tokens) {
        last if !$t;
        my @bunch = @$t[0 .. $last_gov];
        for my $child ( @{$t->[-1]} ) {
            push @bunch, @$child[0 .. $last_factor];
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
);

my ($lang, @factors, @gov_factors, $unit);
GetOptions(
        'language=s'     => \$lang,
        'factors=s'      => \@factors,
        'gov-factors=s'  => \@gov_factors,
        'unit=s'         => \$unit,
);
die "mandatory parameter language not set" if !defined($lang);
die "mandatory parameter unit not set"     if !defined($unit);
die "mandatory parameter factors not set"  if !@factors;

# allow multiple appearances with multiple comma separated values
@factors     = split /,/, join(',', @factors);
@gov_factors = split /,/, join(',', @gov_factors);

if (!@gov_factors) { @gov_factors = @factors }

while (<>) {
    print $sub_for{$unit}->( get_data($unit, $lang, $_), 
                             get_factors($unit, @factors),
                             get_factors($unit, @gov_factors) ), "\n";
}

