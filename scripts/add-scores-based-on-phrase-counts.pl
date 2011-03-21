#!/usr/bin/perl -w

# Adds new scores based on counts of phrases in phrase table.
#
# phr ... phrase pair
# Ce ... count of target part of the phrase pair
# Cf ... count of source part of the phrase pair.
#
# a) --geometric-mean-log=N
# s(phr) = log(sqrt(Ce*Cf))
# N = log basement
#
# b) --counts-log=N
# s1(phr) = log(Ce)
# s2(phr) = log(Cf)
# N = log basement
#
# c) --threshold=N
# s(phr) = exp(1) if (Ce <= N) and (Cf <= N)
#          exp(0) otherwise
#
# d) --log-of-minimum=N
# s(phr) = log(min(Ce, Cf))
# N = log basement
#
# e) --src-threshold=N
# s(phr) = exp(1) if (Cf) <= N
#          exp(0) otherwise
#
# f) --tgt-threshold=N
# s(phr) = exp(1) if (Ce) <= N
#          exp(0) otherwise
#
# You can combine any of above, if you wish. New scores will be written in
# corresponding order.

use strict;
use warnings;
use utf8; # Tell perl this script file is in UTF-8.
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

sub usage_string
{
    print STDERR "Usage: $0 [--geometric-mean-log=N] [--counts-log=N] [--threshold=N] [--log-of-minimum=N] [--src-threshold=N] [--tgt-threshold=N] < phrase-table > modified-phrase-table\n";
    print STDERR "       geometric-mean-log: score(Ce, Cf) = log(sqrt(Ce * Cf)), N determines log basement.\n";
    print STDERR "       counts-log: score1(Ce, Cf) = log(Ce), score2(Ce, Cf) = log(Cf), N determines log basement.\n";
    print STDERR "       threshold: score(Ce, Cf) = exp(1) if (Ce <= N) && (Cf <= N), exp(0) otherwise.\n";
    print STDERR "       log-of-minimum: score(Ce, Cf) = log(min(Ce, Cf)), N determines log basement.\n";
    print STDERR "       src-threshold: score(Ce, Cf) = exp(1) if (Cf <= N), exp(0) otherwise.\n";
    print STDERR "       tgt-threshold: score(Ce, Cf) = exp(1) if (Ce <= N), exp(0) otherwise.\n";
    print STDERR "       Note: if no input is given (eg. via < /dev/null), script only prints out the number of scores that would be added to phrase table.\n";
}

system("renice 19 $$ > /dev/null");

my $gm_log = 0;
my $counts_log = 0;
my $threshold = 0;
my $log_of_minimum = 0;
my $src_threshold = 0;
my $tgt_threshold = 0;

if ( !GetOptions(
        "geometric-mean-log=i" => \$gm_log,
        "counts-log=i" => \$counts_log,
        "threshold=i" => \$threshold,
		"log-of-minimum=i" => \$log_of_minimum,
		"src-threshold=i" => \$src_threshold,
		"tgt-threshold=i" => \$tgt_threshold,
	)
) {
		die(usage_string());
}

if ( !$gm_log and !$counts_log and !$threshold and !$log_of_minimum and !$src_threshold and !$tgt_threshold) {
		die(usage_string());
}

my $delimiter = '\|\|\|';
my $joiner = '|||';

sub geometric_mean {
	my ($a, $b) = @_;
	return sqrt ($a * $b);
}

sub my_log {
	my ($n, $base) = @_;
	return log($n) / log($base);
}

# Score 1 counter.
sub gm_log {
    my ($base, $e_count, $f_count) = @_;
    return sprintf '%f', my_log(geometric_mean($e_count, $f_count), $base);
}

# Score 2 counter.
sub counts_log {
    my ($base, $e_count, $f_count) = @_;
    return sprintf '%f %f', my_log($e_count, $base), my_log($f_count, $base);
}

# Score 3 counter.
sub threshold {
	my ($threshold, $e_count, $f_count) = @_;
	return sprintf '%f', exp(($e_count <= $threshold) and ($f_count <= $threshold));
}

# Score 4 counter.
sub log_of_minimum {
    my ($base, $e_count, $f_count) = @_;
	# Perl apparently don't have builtin min/max functions... Guido, I miss you.
    return sprintf '%f', my_log(($e_count, $f_count)[$e_count > $f_count], $base);
}

# Score 5 and 6 counter.
sub single_count_threshold {
	my ($threshold, $count) = @_;
	return sprintf '%f', exp($count <= $threshold);
}

# Processing...

my $no_input = 1;

while (<>) {

	$no_input = 0;

	my $line = $_;
	
	my ($f_phrase, $e_phrase, $scores, $alignment, $counts) = split $delimiter, $line;

	chomp $counts;

	my ($e_count, $f_count) = split ' ', $counts;

	my $additional_scores = '';

	if ( $gm_log ) {
		$additional_scores .= gm_log($gm_log, $e_count, $f_count) . ' ';
	}
	if ( $counts_log ) {
		$additional_scores .= counts_log($counts_log, $e_count, $f_count) . ' ';
	}
	if ( $threshold ) {
		$additional_scores .= threshold($threshold, $e_count, $f_count) . ' ';
	}
	if ( $log_of_minimum ) {
		$additional_scores .= log_of_minimum($log_of_minimum, $e_count, $f_count) . ' ';
	}
	if ( $src_threshold ) {
		$additional_scores .= single_count_threshold($src_threshold, $f_count) . ' ';
	}
	if ( $tgt_threshold ) {
		$additional_scores .= single_count_threshold($tgt_threshold, $e_count) . ' ';
	}

	print join ($joiner, $f_phrase, $e_phrase, $scores . $additional_scores, $alignment, $counts) . "\n";
}

if ( $no_input ) {
	my $scores_count = 0;
	$scores_count += 1 if $gm_log;
	$scores_count += 2 if $counts_log;
	$scores_count += 1 if $threshold;
	$scores_count += 1 if $log_of_minimum;
	$scores_count += 1 if $src_threshold;
	$scores_count += 1 if $tgt_threshold;
	print $scores_count;
}

