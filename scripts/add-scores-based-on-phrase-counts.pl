#!/usr/bin/perl -w

# Adds new scores based on counts of phrases in phrase table.
# 
# a) geometric-mean-log
# s(phr) = log(g-mean(c(e), c(f)))
#
# b) counts-log
# s1(phr) = log(c(e))
# s2(phr) = log(c(f))
#
# c) both of above above scores
#
# Log basement may be also specified (default is 2).

use strict;
use warnings;
use utf8; # Tell perl this script file is in UTF-8.
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

sub usage_string
{
    print STDERR "Usage: $0 [--geometric-mean-log] [--counts-log] [--log-base N] < phrase-table > modified-phrase-table\n";
    print STDERR "       geometric-mean-log: score0(Ce, Cf) = log(sqrt(Ce * Cf))\n";
    print STDERR "       counts-log: score1(Ce, Cf) = log(Ce), score2(Ce, Cf) = log(Cf)\n";
    print STDERR "       log-base: determines the base of logarithm in formulas above.\n";
}

system("renice 19 $$ > /dev/null");

my ($gm_log, $counts_log);
my $log_base = 2;

if ( !GetOptions(
        "geometric-mean-log" => \$gm_log,
        "counts-log" => \$counts_log,
        "log-base=i" => \$log_base
	)
) {
		die(usage_string());
}

if ( !$gm_log and !$counts_log ) {
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

# Processing...

while (<>) {

	my $line = $_;
	
	my ($f_phrase, $e_phrase, $scores, $alignment, $counts) = split $delimiter, $line;

	chomp $counts;

	my ($e_count, $f_count) = split ' ', $counts;

	my $additional_scores = '';

	if ( $gm_log ) {
		$additional_scores .= gm_log($log_base, $e_count, $f_count) . ' ';
	}
	if ( $counts_log ) {
		$additional_scores .= counts_log($log_base, $e_count, $f_count) . ' ';
	}

	print join ($joiner, $f_phrase, $e_phrase, $scores . $additional_scores, $alignment, $counts) . "\n";
}

