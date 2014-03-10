#!/usr/bin/perl -w
use strict;

#usage
#eman tb --stat s.evaluator.* > my_traceback.txt
#./make_graph.pl < my_traceback.txt > graph.dot
#dot -Tpng graph.dot -o file.png

my @stack;
my $depth=-1;
my %status;
my %color_for=(DONE=>"green", FAILED=>"red", RUNNING=>"blue", INITED=>"yellow", PREPFAILED=>"coral", PREPARED=>"lightblue");

print "digraph G {\n";

my %printed;
while(<STDIN>){
	if(/^((?:\|  )*)\+- (.+)/){
		my $new_depth=(length $1)/3;
		my $step=$2;

		if($new_depth<=$depth){
			for (0..$depth-$new_depth){
				pop @stack;
			}
		}

		if(@stack and not $printed{$stack[$#stack].' '.$step}){
			print "\t\"$stack[$#stack]\" -> \"$step\" ;\n";
			$printed{$stack[$#stack].' '.$step}=1;
		}
		$depth=$new_depth;
		push @stack, $step;
	}elsif(/^(?:\|  )*\| Job: (RUNNING|INITED|PREPFAILED|FAILED|DONE|PREPARED)/){
		$status{$stack[$#stack]}=$1;
	}
}

foreach my $step (keys %status){
	print "\t\"$step\" [color=".$color_for{$status{$step}}."];\n";
}

print "}\n";

