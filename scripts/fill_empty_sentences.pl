#!/usr/bin/perl
# Prázdné řádky nahradí řádky, které obsahují jedno podtržítko.
# Slouží jako ochrana pro nástroje, které špatně snášejí prázdné věty (třeba augment.pl).
# Vhodnější by bylo takové věty úplně odstranit, ale to by se muselo udělat souběžně ve všech jazycích, což je těžší.
# Copyright © 2010 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    s/\r?\n$//;
    if(m/^\s*$/)
    {
        $_ = '_';
    }
    print("$_\n");
}
