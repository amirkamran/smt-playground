#!/usr/bin/perl
# Reads parallel text files (lines = sentences, same number in each file) and writes out a specified portion.
# Useful for splitting a corpus into training and test part. (One could also use the Linux 'head' and 'tail'
# commands but this way the test sentences will be more evenly distributed among the various documents and
# domains the corpus may contain.)
# Copyright © 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
sub usage
{
    print STDERR ("Usage: every_nth_parallel_sentence.pl -n|-N 10 -i inputbasename -o outputbasename -l1 fr -l2 en > output\n");
    print STDERR ("       will read inputbasename.fr and inputbasename.en\n");
    print STDERR ("       will write outputbasename.fr and outputbasename.en\n");
    print STDERR ("       -n 10: output contains every tenth sentence of input\n");
    print STDERR ("       -N 10: output contains everything except every tenth sentence of input\n");
    print STDERR ("Poznámka DZ: Nějak jsem si neuvědomil, že když výběr řádků nezávisí na obsahu, tak nemusím psát skript, který vybírá z obou paralelních půlek zároveň. Klidně se mohl napsat mnohem jednodušší skript, který se pustí na každou půlku zvlášť.\n");
}

use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long qw(:config no_ignore_case);

GetOptions
(
    'n=i' => \$ntake,
    'N=i' => \$nskip,
    'i=s' => \$inputbasename,
    'o=s' => \$outputbasename,
    'l1=s' => \$language1,
    'l2=s' => \$language2
);
unless($inputbasename && $outputbasename && $language1 && $language2 && ($ntake || $nskip) && !($ntake && $nskip))
{
    usage();
    if($ntake && $nskip)
    {
        die("Please specify either -n or -N but not both.\n");
    }
    else
    {
        die();
    }
}
open(IN1, "$inputbasename.$language1") or die("Cannot read from $inputbasename.$language1: $!\n");
open(IN2, "$inputbasename.$language2") or die("Cannot read from $inputbasename.$language2: $!\n");
open(OUT1, ">$outputbasename.$language1") or die("Cannot write to $outputbasename.$language1: $!\n");
open(OUT2, ">$outputbasename.$language2") or die("Cannot write to $outputbasename.$language2: $!\n");
$i_line = 0;
while(<IN1>)
{
    my $in1 = $_;
    my $in2 = <IN2>;
    $i_line++;
    if(($ntake && ($i_line % $ntake == 0)) || ($nskip && ($i_line % $nskip != 0)))
    {
        print OUT1 ($in1);
        print OUT2 ($in2);
    }
}
close(IN1);
close(IN2);
close(OUT1);
close(OUT2);
