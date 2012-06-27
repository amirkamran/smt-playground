#!/usr/bin/perl
# Copyright 2003-2004 Vlado Keselj www.cs.dal.ca/~vlado

sub help { print <<"#EOT" }
# Find equal files in a directory tree, version $VERSION
#
# Relies on diff.
#
# Usage: find-equal-files [switches] [directories]
#  -n  find equal files even if they have different names
#  -i  report equal files as found, beside the final report
#  -h  Print help and exit.
#  -v  Print version of the program and exit.
#EOT

use strict;
use vars qw( $VERSION %Tab );
$VERSION = sprintf "%d.%d", q$Revision: 1.6 $ =~ /(\d+)/g;

use Getopt::Std;
use vars qw($opt_v $opt_h $opt_n $opt_i);
getopts("vhni");

if ($opt_v) { print "$VERSION\n"; exit; }
elsif ($opt_h || !@ARGV) { &help(); exit; }

$| = 1;
&find_equal_files(@ARGV);

print "FINAL REPORT:\n";
foreach my $k (keys %Tab) {
    foreach my $e (@{ $Tab{$k} }) {
	next unless @{ $e->{otherfiles} };
	print "equal files: $e->{file0}\n";
	foreach my $f (@{ $e->{otherfiles} }) { print "        and: $f\n" }
    }
}

sub find_equal_files {
    while ($#_ > -1) {
	my $dir = shift;

	next if -l $dir || !-e $dir; # symbolic link or does not exist: ignore it

	if (not -d $dir) {	                  # a file
	    my $size = ((stat $dir)[7]);
	    my $basename = $dir;
	    if ($dir =~ /\/([^\/]+)$/) { $basename = $1 }
	    my $key = $opt_n ? $size : "$basename $size";

	    if (exists $Tab{$key}) {              # Could be equal
		local $_;
		foreach ( @{ $Tab{$key} } ) {
		    local(*SAVEOUT, *SAVEERR); # temporarily redirect STDOUT
		    open(SAVEOUT, ">&STDOUT");
		    open(SAVEERR, ">&STDERR");
		    open(STDOUT, ">/dev/null") ||
			die "Can't redirect stdout to /dev/null";
		    open(STDERR, ">/dev/null") ||
			die "Can't redirect stdout to /dev/null";

		    my $r = system('diff', $_->{file0}, $dir) / 256;

		    close(STDERR); open(STDERR, ">&SAVEERR");
		    close(STDOUT); open(STDOUT, ">&SAVEOUT");

		    if ($r == 0) {
			push @{ $_->{otherfiles} }, $dir;
			if ($opt_i)
			{ print "equal files:$_->{file0}\n        and:$dir\n" }
			goto FOUND_SAME;
		    }
		}
		push @{ $Tab{$key} }, { file0=>$dir, otherfiles=>[] };
	      FOUND_SAME:
	    }
	    else { $Tab{$key} = [ { file0=>$dir, otherfiles=>[] } ] }
	    next;
	}
	
	local ($_, *DIR); 	                  # recursively enter directory
	opendir(DIR, $dir) || die "can't opendir $dir: $!";
	map { /^\.\.?$/ ? '' : (&find_equal_files("$dir/$_")) } readdir(DIR);
	closedir(DIR);
    }
}
