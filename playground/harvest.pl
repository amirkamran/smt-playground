#!/usr/bin/env perl
# Collects BLEU scores from evaluator steps.
# Copyright © 2012-2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
sub usage
{
    print STDERR ("Usage: harvest.pl [-usr <user> -psw <password>] > harvest.txt\n");
    print STDERR ("Options:\n");
    print STDERR ("       -usr: user name for matrix.statmt.org\n");
    print STDERR ("       -psw: password\n");
    print STDERR ("Creates a table of known results, sorted by languages, test sets and scores.\n");
    print STDERR ("If the credentials for matrix.statmt.org are provided, submits best results there!\n");
    print STDERR ("BEWARE: Understand what the submission scripts do before using them!\n");
}
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Carp;
use Getopt::Long;
use dzsys;

GetOptions
(
    'usr=s' => \$usr,
    'psw=s' => \$psw,
);
# Make sure that all evaluator steps have a tag that identifies the corpora used.
dzsys::saferun("eman retag") or die;
# Ask Eman to collect names, states, tags and scores of all evaluator steps.
if(!-f 'eman.results.conf')
{
    open(CONF, ">eman.results.conf") or die("Cannot write eman.results.conf: $!");
    print CONF ("*\ts.evaluator*/scores\tCMD: perl -F'\\t' -lane '\$F[1] =~ s/[\\[\\]]//g; (\$lo, \$hi) = split /,/, \$F[1]; printf \"\$F[0]\\t%.2f±%.2f\\n\", \$F[0]*100, (\$hi-\$lo)/2*100;'\n");
#    print CONF ("Snts\ts.evaluator*/corpus.translation\tCMD: wc -l\n");
    close(CONF);
}
dzsys::saferun("eman collect") or die;
# Read the results collected by Eman and sort them.
open(RES, 'eman.results') or die("Cannot read eman.results: $!");
while(<RES>)
{
    chomp();
    my @fields = split(/\t/, $_);
    # For some reason, eman.results contain several lines for each step.
    # Only one of the lines contains the BLEU scores we are after.
    next if($fields[2] =~ m/^(Snts|TAG)$/);
    my %record =
    (
        'step'    => $fields[0],
        'state'   => $fields[1],
        'bleu'    => $fields[2],
        'bleuint' => $fields[3],
        'tags'    => $fields[4]
    );
    next unless($record{state} eq 'DONE');
    if($record{tags} =~ m/S:(.*?)\s+T:(.*?)\s/)
    {
        $record{pair} = "$1-$2";
    }
    # We need a language pair identifier to sort the results.
    # If the pair is unknown for any reason, choose xx-yy instead but do not leave it empty.
    else
    {
        $record{pair} = 'xx-yy';
    }
    # As we currently have a mixture of translate steps run either on wmt2012 or wmt2013 test sets, we want to sort the results according to this as well.
    if($record{tags} =~ m/TST:(\S+)/)
    {
        $record{test} = $1;
    }
    else
    {
        $record{test} = 'zzz'; # last in alphabet
    }
    push(@results, \%record);
}
close(RES);
@results = sort
{
    my $vysledek = $a->{pair} cmp $b->{pair};
    unless($vysledek)
    {
        $vysledek = $a->{test} cmp $b->{test};
        unless($vysledek)
        {
            $vysledek = $b->{bleu} <=> $a->{bleu};
        }
    }
    return $vysledek;
}
(@results);
foreach my $r (@results)
{
    # Separate language pairs and test sets by horizontal lines.
    if($lastpair && $r->{pair} ne $lastpair)
    {
        print('=' x 80, "\n");
    }
    elsif($lasttest && $r->{test} ne $lasttest)
    {
        print('.' x 80, "\n");
    }
    # Submit results if required.
    if($usr && $psw)
    {
        # Is this the best result for the given language pair and for the required test set?
        if(!defined($lastpair) || $r->{pair} ne $lastpair || !defined($lasttest) || $r->{test} ne $lasttest)
        {
            # This is the first, i.e. best scored result for the given language pair and test set.
            # Is it the required test set?
            if($r->{test} eq 'wmt2013')
            {
                print('!'); # Mark submitted experiments in the harvest overview.
                print STDERR ("Submitting $r->{step} ($r->{pair})...\n");
                dzsys::saferun("presubmit.pl $r->{step} cu-zeman") or die;
                dzsys::saferun("matrix_submit_results.pl -usr $usr -psw $psw -step $r->{step}") or die;
            }
        }
    }
    print("$r->{pair}\t$r->{bleu}\t$r->{bleuint}\t$r->{tags}\t$r->{step}\n");
    $lastpair = $r->{pair};
    $lasttest = $r->{test};
}
