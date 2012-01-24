#!/usr/bin/env perl
# Removes superfluous spaces from tokenized text. The output contains only SPACE or LF.
# Ensures that the last line is terminated by a LF character even if it was originally not.
# Also warns about empty lines but does not remove them (in parallel corpus other files could also be affected).
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

while(<>)
{
    s/\r?\n$//;
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /;
    print("$_\n");
}
