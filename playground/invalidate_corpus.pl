#!/usr/bin/env perl
# If we discover that a corpus was prepared incorrectly, this script makes sure
# that neither the corpus nor anything based on it is used again (without
# physically removing the steps or the data; you have to clean up yourself if
# desired).
# Copyright © 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
sub usage
{
    print STDERR ("invalidate_corpus.pl s.corpus.bad\n");
}



use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;
use Carp;
use dzsys;



# Get the name of the bad step. Does it exist? Is it a corpus step (is there a corpman.info file)?
if(scalar(@ARGV) != 1)
{
    usage();
    confess();
}
my $step0 = $ARGV[0];
if(! -d $step0)
{
    print STDERR ("WARNING: $step0 does not exist or it is not a folder.\n");
}
if(! -f "$step0/corpman.info")
{
    print STDERR ("WARNING: $step0 does not seem to be a corpus step. There is no corpman.info file.\n");
}
# First show the tree of descendants so that the user knows what is going to be invalidated.
dzsys::saferun("eman tf $step0 --status --tag") or confess();
print("ALL THE ABOVE STEPS WILL BE INVALIDATED. IF IN DOUBT, PRESS CTRL+C NOW.\n");
dzsys::autoflush(*STDOUT); for(my $i = 10; $i > 0; $i--) { print("$i ... "); sleep(3); } print("GO!\n");
my @steps = split(/\r?\n/, dzsys::safeticks("eman tf $step0 --notree | sort -u"));
foreach my $step (@steps)
{
    dzsys::saferun("eman fail $step") or confess();
    if(-f "$step/corpman.info")
    {
        dzsys::saferun("mv $step/corpman.info $step/corpman.info.bad") or confess();
    }
}
print("TOTAL ", scalar(@steps), " steps.\n");
dzsys::saferun('corpman reindex') or confess();
