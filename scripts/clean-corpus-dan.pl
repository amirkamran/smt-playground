#!/usr/bin/perl
# Removes from parallel corpus sentences that are too short or too long.
# Same goal as the clean-corpus-n.perl script by Hieu Hoang, shipped with Moses.
# Different args though: any number of language and alignment files (paths include the final language extension).
# Sentences are removed parallely from all languages and/or alignments.
# Number of tokens is checked in languages but not in alignments.
# Alignment lines are recognized on the fly (if it consists only of N-M tokens, it is an alignment line).
# Copyright © 2010 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

sub usage
{
    print STDERR ("Usage: clean-corpus-dan.pl -min 1 -max 99 corpus/train.fr [corpus/train.en [model/train.ali [...]]]\n");
    print STDERR ("       Removes parallel sentences if at least one language has less than min or more than max tokens.\n");
    print STDERR ("       Default is: -min 0 -max 0\n");
    print STDERR ("       -max 0 means no upper limit.\n");
    print STDERR ("       Input files may or may not be gzipped (recognized by the .gz extension).\n");
    print STDERR ("       The cleaned output files have the extension .clean (rename yourself).\n");
}

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long;

$min = 0;
$max = 0;
GetOptions('min=i' => \$min, 'max=i' => \$max);
$min = 0 if($min<0);
$max = 0 if($max<0);
@infiles = @ARGV;
if(scalar(@infiles)<1)
{
    usage();
    die("No argument found.\n");
}
print STDERR ("Removing all sentences having less than $min tokens.\n") if($min>0);
print STDERR ("Removing all sentences having more than $max tokens.\n") if($max>0);
# Decide what files are gzipped and open all input and output files.
@files;
foreach my $if (@infiles)
{
    my %file;
    if($if =~ m/^(.*?)\.gz$/)
    {
        my $base = $1;
        $file{in} = "gunzip -c $if |";
        $file{out} = "| gzip -c > $base.clean.gz";
    }
    else
    {
        $file{in} = $if;
        $file{out} = "> $if.clean";
    }
    my $ih;
    my $oh;
    open($ih, $file{in}) or die("Cannot open '$file{in}': $!\n");
    open($oh, $file{out}) or die("Cannot open '$file{out}': $!\n");
    $file{ih} = $ih;
    $file{oh} = $oh;
    print STDERR ("$file{in} => $file{out}\n");
    push(@files, \%file);
}
# Read input files, filter lines and write output files.
# All files should have the same number of lines!
my $n_lines_read = 0;
my $n_lines_written = 0;
while(1)
{
    # Has any of the input files ended?
    my $eof = 0;
    foreach my $f (@files)
    {
        if(eof($f->{ih}))
        {
            $eof = 1;
            last;
        }
        # Read the next line from the input file.
        else
        {
            my $handle = $f->{ih};
            $f->{line} = <$handle>;
        }
    }
    last if($eof);
    $n_lines_read++;
    # Show progress meter.
    if($n_lines_read % 10000 == 0)
    {
        if($n_lines_read % 100000 == 0)
        {
            print STDERR ("($n_lines_read)");
        }
        else
        {
            print STDERR ('.');
        }
    }
    # Check all input lines.
    my $ok = 1;
    foreach my $f (@files)
    {
        ###!!! DEBUG
        #print($f->{line});
        # Strip the line break.
        $f->{line} =~ s/\r?\n$//;
        # Is this an alignment line?
        # Note: empty alignment will not be recognized as alignment. It will be considered empty text, which may lead to removing this sentence.
        $f->{alignment} = $f->{line} =~ m/^(\d+-\d+\s*)+$/;
        # Check number of tokens.
        unless($f->{alignment})
        {
            my @tokens = split(/\s+/, $f->{line});
            $f->{tokens} = \@tokens;
            my $n = scalar(@tokens);
            if($min && $n<$min || $max && $n>$max)
            {
                $ok = 0;
                last;
            }
        }
    }
    # Write all output lines.
    if($ok)
    {
        foreach my $f (@files)
        {
            my $handle = $f->{oh};
            print $handle ("$f->{line}\n");
        }
        $n_lines_written++;
    }
}
# Terminate the progress meter.
print STDERR ("\n");
# Close all files.
foreach my $f (@files)
{
    close($f->{ih});
    close($f->{oh});
}
# Write the final report.
print STDERR ("Read $n_lines_read lines from each input file.\n");
print STDERR ("Written $n_lines_written lines to each output file.\n");
