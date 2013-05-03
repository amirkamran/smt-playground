#!/usr/bin/env perl
# Prepares an MT experiment for submission to the WMT site http://matrix.statmt.org/.
# Copyright © 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use dzsys;

sub usage
{
    print STDERR ("Usage: presubmit.pl s.evaluator.xxx.yyy-zzz system-name\n");
    print STDERR ("The script prepares everything for submission but does not yet submit the results.\n");
    print STDERR ("The system name is typically identical for all experiments submitted by one user.\n");
}

# We need the original SGML file. We expect it to be stored outside the playground, in a fixed path.
$sgmlpath = '/net/data/wmt/test';
$year = 2013;
# We require the STATMT environment variable to point to the local StatMT repository (ÚFAL playground).
if(!exists($ENV{STATMT}))
{
    die('$STATMT environment variable is not defined');
}
$scriptpath = "$ENV{STATMT}/scripts";
if(! -d $scriptpath)
{
    die("The scripts folder '$scriptpath' does not exist");
}
# The experiment to submit is defined by its evaluator step.
$estep = $ARGV[0];
if($estep !~ m/^s\.evaluator\./)
{
    usage();
    die(defined($estep) ? "Argument '$estep' is not an evaluator step." : "Undefined argument (evaluator step)");
}
chdir($estep) or die("Cannot go to folder $estep: $!");
# The second argument must be the name of the system. It will be stored in the output file.
$sysname = $ARGV[1];
if(!defined($sysname))
{
    usage();
    die("Missing name of the MT system");
}
# Read the eman tags of the evaluator step and determine the language pair.
($dummy, $tags) = split(/\t/, dzsys::chompticks("eman tag $estep"));
@tags = split(/\s+/, $tags);
foreach my $tag (@tags)
{
    if($tag =~ m/^S:(.+)$/)
    {
        $src = $1;
    }
    elsif($tag =~ m/^T:(.+)$/)
    {
        $tgt = $1;
    }
}
# Find the SGML source file for the given source language.
$sgmlsrc = "$sgmlpath/newstest$year-src.$src.sgm";
if(! -f $sgmlsrc)
{
    die("$sgmlsrc not found");
}
# Create the file to submit.
dzsys::saferun("cat corpus.translation | $scriptpath/capitalize_sentences.pl | $scriptpath/detokenizer.pl -l $tgt > sysout.detok.txt") or die;
dzsys::saferun("cat sysout.detok.txt | $scriptpath/normalize-punctuation.pl $tgt > sysout.detok.normalized.txt") or die;
dzsys::saferun("cat sysout.detok.txt | $scriptpath/wrap-xml.pl $tgt $sgmlsrc $sysname > sysout.$tgt.sgml") or die;
dzsys::saferun("cat sysout.detok.normalized.txt | $scriptpath/wrap-xml.pl $tgt $sgmlsrc $sysname > sysout.$tgt.normalized.sgml") or die;
print("To submit the results to the WMT site, call:\n");
print("\tmatrix_submit_results.pl -usr YOUR_USER_NAME -psw YOUR_PASSWORD -src $src -tgt $tgt -notes $estep sysout.$tgt.sgml\n");
print("\tmatrix_submit_results.pl -usr YOUR_USER_NAME -psw YOUR_PASSWORD -src $src -tgt $tgt -notes $estep sysout.$tgt.normalized.sgml\n");
