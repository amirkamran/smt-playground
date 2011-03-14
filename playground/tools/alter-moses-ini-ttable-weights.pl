#!/usr/bin/perl -w

# Alters (default) moses.ini file by setting up additional weights to phrase
# table.
# 
# Usage: script.pl number-of-scores-to-add

use strict;
use warnings;
use utf8; # Tell perl this script file is in UTF-8.

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

my $scores_to_add = shift;
my $scores_count = 0;

while (<>) {
	my $line = $_;
	chomp $line;

	if ( $line eq '[ttable-file]' ) {
		print $line . "\n";
		$line = <>;
		chomp $line;
		#
		my @chunks = split ' ', $line; # Break into pieces.
		my $old_scores_count = $chunks[3]; # We're assuming new format of moses.ini.
		$scores_count = $old_scores_count + $scores_to_add; # Evaluate.
		$chunks[3] = $scores_count; # Replace.
		$line = join ' ', @chunks; # Glue back together.
	}
	elsif ( $line eq '[weight-t]' ) {
		print $line . "\n";
		$line = <>;
		chomp $line;
		while ( $line ne '' ) {
			# Skip old weights.
			$line = <>;
			chomp $line;
		}
		for ( my $i = 0; $i < $scores_count; ++$i ) {
			printf "%f\n", (1 / $scores_count);
		}
	}
	
	# (empty line)
	print $line . "\n";
}

