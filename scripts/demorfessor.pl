#!/usr/bin/env perl
# Slepí text rozsekaný na morfémy Morfessorem. Vhodné zejména když podobný text vypadl ze strojového překladu.
# Copyright © 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

while(<>)
{
    chomp();
    s-/STM--g;
    s-/PRE\+\s+--g;
    s-\s+\+(\S+?)/SUF--g;
    print("$_\n");
}
