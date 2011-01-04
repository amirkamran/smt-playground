#!/usr/bin/env perl

# USAGE: ./extract_units.pl --language=cs|en \
#                           --unit=anode|tnode|tpair \ 
#                           --factors=<comma separated anode or tnode factors>
# 
# Factors can be specified by their names or positions (counted from 0).
#
# DESCRIPTION: The script takes CzEng export format as input and outputs
# anodes/tnodes of selected language. The nodes only contain requested
# factors.
# 
# TODO: Also support output of forks and bunches
#
# Miroslav Tynovsky
#

use strict;
use warnings;
use utf8;
use Getopt::Long qw( GetOptions );

sub get_data {
    my ($unit, $lang, $line) = @_;
    
    # order + offset = index of line part for given lang and tree/alignment
    my %offset_of_lang = (cs => 5, en => 1);
    my %order_of_part  = (a => 0, t => 1, lexrf => 2, auxrf => 3);

    my $offset = $offset_of_lang{$lang};
    die "unknown language\n" if not defined $offset;
    my @line_parts = split /\t/, $line;

    return ($unit eq 'anode') ? $line_parts[$order_of_part{a} + $offset]
         : ($unit eq 'tnode') ? $line_parts[$order_of_part{t} + $offset]
         : ($unit eq 'tpair') ? $line_parts[$order_of_part{t} + $offset]
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
    if ($unit eq 'tpair') { push @factors, 'gov' }

    #convert index or name of factor to index of factor
    return map { /\d+/ ? $_ : $order_of_factor{$tree}->{$_} } @factors;
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
    pop @factors; #get rid of gov
    my @pairs;
    for my $t (@tokens) {
        #print STDERR join('|', @$t), "\n";
        next if $t->[-1] == 0; #root
        my $gov = $tokens[ $t->[-1] - 1 ];
        push @pairs, join '|', @$t[@factors], @$gov[@factors];
    }
    return join ' ', @pairs;
}

#============================================================================

my %sub_for = (
    anode     => \&node,
    tnode     => \&node,
    tpair     => \&pair,
    tbunch    => sub {die "not implemented\n"},
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

