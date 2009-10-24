#!/usr/bin/perl
#===============================================================================
#
#        USAGE:  ./count_oov.pl --train path/to/train.gz --test path/to/test.gz
#
#  DESCRIPTION: Count how many types and tokens from test data were unseen in
#               the train data.
#               Output is formated for DocuWiki.
#===============================================================================

use strict;
use warnings;
use open qw/:utf8 :std/;
use Getopt::Long;
use List::Util qw/sum/;

my ($train, $test);
my $opts = GetOptions('train=s' => \$train, 'test=s' => \$test);

my ($train_tokens, $train_types, %train_words) = count($train);
my ($test_tokens, $test_types, %test_words) = count($test);
print "|  train:  |  $train_tokens  |  $train_types  |\n", 
      "|  test:  |  $test_tokens  |  $test_types  |\n";

# out of vocabulary
delete @test_words{keys %train_words};
my $oov_tokens = sum(values %test_words);
my $oov_types = scalar keys %test_words;
my $perc_tok_oov = sprintf( "%.3f", $oov_tokens / $test_tokens * 100);
my $perc_typ_oov = sprintf( "%.3f", $oov_types / $test_types * 100);
print 
"|  OOV:  |  $oov_tokens ($perc_tok_oov%)  |  $oov_types ($perc_typ_oov%)  |\n";


#####
sub count {
    my $in_filename = shift;
    open( my $in, '-|:utf8', "zcat $in_filename" );
    my %words;
    while (<$in>) {
        chomp;
        map { $words{$_}++ } split /\s+/, $_;
    }
    return sum(values %words), scalar keys(%words), %words;
}
