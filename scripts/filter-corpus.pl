#!/usr/bin/perl
# Reads from STDIN numbers of lines to select from a parallel corpus.
# This can be output of overlap.pl with multiple numbers per line; default is to read the first one and ignore the rest.
# Arguments are paths to any number of input files forming the parallel corpus, and paths to the respective output files.
# Copyright © 2010 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

sub usage
{
    print STDERR ("Usage: filter-corpus.pl [-l|-r] < linenos.txt infile1 outfile1 [infile2 outfile2 [...]]\n");
    print STDERR ("       STDIN contains numbers of selected lines (they do not need to be ordered).\n");
    print STDERR ("       -l ... The first (left) number on every line is used, others are ignored. Default.\n");
    print STDERR ("       -r ... The second (right) number on every line is used, others are ignored.\n");
    print STDERR ("       Reads all input files and writes the selected lines to the respective output files.\n");
    print STDERR ("       Input files may or may not be gzipped (recognized by the .gz extension).\n");
}

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long;
use dzsys;

# Czech: left = levý, right = pravý. Hence the alias -p for -r.
GetOptions('l' => \$left_numbers, 'r' => \$right_numbers, 'p' => \$right_numbers);
if($left_numbers && $right_numbers || !$left_numbers && !$right_numbers)
{
    $left_numbers = 1;
    $right_numbers = 0;
}
$nargs = scalar(@ARGV);
if($nargs<1 || $nargs % 2 == 1)
{
    usage();
    die("No argument found.\n");
}
# Read numbers of selected lines from the standard input.
while(<STDIN>)
{
    # Remove the line break.
    s/\r?\n$//;
    # Split the line into tokens (all tokens should be positive integer numbers).
    my @numbers = split(/\s+/, $_);
    my $number = $left_numbers ? $numbers[0] : $numbers[1];
    # Check that what we got is a positive integer number.
    if($number !~ m/^\d+$/ || $number==0)
    {
        print STDERR ("STDIN ERROR: $_\n");
        die("All line numbers must be positive integers.\n");
    }
    push(@linenos, $number);
}
# Decide what files are gzipped and open all input and output files.
for(my $i = 0; $i<=$#ARGV; $i += 2)
{
    my %file;
    $file{in} = $ARGV[$i];
    $file{out} = $ARGV[$i+1];
    $file{hi} = dzsys::gopen($ARGV[$i]);
    $file{ho} = dzsys::gwopen($ARGV[$i+1]);
    print STDERR ("$file{in} => $file{out}\n");
    push(@files, \%file);
}
# The numbers of the selected lines may not be ordered.
# We cannot apply sort() on them. If they have been output of overlap.pl,
# we have to keep the order in which overlap.pl reported them so that
# the synchronization with the other parallel corpus is kept.
# Thus, we must read the whole file into memory (array of lines) and then select them by numbers.
foreach my $f (@files)
{
    # Read all lines of the input file.
    my $in = $f->{hi};
    my @lines;
    while(<$in>)
    {
        push(@lines, $_);
    }
    my $n = scalar(@lines);
    # Write selected lines to the output file.
    my $out = $f->{ho};
    foreach my $l (@linenos)
    {
        if($l<=0)
        {
            die("The number of the first line is 1. Required line no. $l.\n");
        }
        elsif($l>$n)
        {
            die("Input file $f->{in} has only $n lines. Required line no. $l.\n");
        }
        print $out ($lines[$l-1]);
    }
}
# Close all files.
foreach my $f (@files)
{
    close($f->{hi});
    close($f->{ho});
}
