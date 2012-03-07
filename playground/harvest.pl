#!/usr/bin/env perl
# Collects BLEU scores from evaluator steps.
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use dzsys;

# Make sure that all evaluator steps have a tag that identifies the corpora used.
dzsys::saferun("tagevals > /dev/null") or die;
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
    if($record{tags} =~ m/SRCAUG=(.*?),TGTAUG=(.*?),/)
    {
        $record{pair} = "$1-$2";
        # We may concern about factors later but currently there is always '+stc'.
        $record{pair} =~ s/\+stc//g;
    }
    # We are only interested in the first combined tag ("A:SRCAUG..."). Erase the rest.
    $record{tags} =~ s/^(A:SRCAUG=\S+).*$/$1/;
    push(@results, \%record);
}
close(RES);
@results = sort
{
    my $vysledek = $a->{pair} cmp $b->{pair};
    unless($vysledek)
    {
        $vysledek = $b->{bleu} <=> $a->{bleu};
    }
    return $vysledek;
}
(@results);
foreach my $r (@results)
{
    if($lastpair && $r->{pair} ne $lastpair)
    {
        print('-' x 80, "\n");
    }
    print("$r->{pair}\t$r->{bleu}\t$r->{bleuint}\t$r->{tags}\t$r->{step}\n");
    $lastpair = $r->{pair};
}
