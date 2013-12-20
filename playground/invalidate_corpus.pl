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
my $step0 = $ARGV[0];
if(! -d $step0)
{
    print STDERR ("WARNING: $step0 does not exist or it is not a folder.\n");
}
if(! -f "$step0/corpman.info")
{
    print STDERR ("WARNING: $step0 does not seem to be a corpus step. There is no corpman.info file.\n");
}
dzsys::saferun("eman tf $step0 --notree | sort -u") or confess();
