#!/usr/bin/perl
# Normalizuje některé znaky v hindštině.
# (c) 2008 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    # Kontrola: zjistit počet tokenů před transformacemi.
    my $n_pred = scalar(split(/\s+/, $_));
    my $pred = $_;
    # Nahradit číslice z dévanágarí euro-arabskými (v hindštině se může objevit obojí).
    tr/\x{966}\x{967}\x{968}\x{969}\x{96A}\x{96B}\x{96C}\x{96D}\x{96E}\x{96F}/0123456789/;
    # Nahradit dandu tečkou.
    s/\x{964}/./g;
    # Nahradit dvojitou dandu tečkou (možná by se hodil jiný znak, ale nevím jaký).
    s/\x{965}/./g;
    # Nahradit znaménko zkratky z dévanágarí tečkou.
    s/\x{970}/./g;
    # Nahradit visarg dvojtečkou. Není to sice zdaleka totéž, ale vypadají stejně a autoři si je někdy na klávesnici pletou.
#    s/\x{903}/:/g;
    # Odstranit zero width joiner (v některých datech se objevuje za virámem).
    # Pozor, kdyby se náhodou objevil jako jediný znak tokenu, odstranit ho z technických důvodů nesmíme, změnil by se počet tokenů.
    s/(\w)\x{200D}(\w)/$1$2/g;
    # Kontrola: zkontrolovat počet tokenů po transformacích.
    my $n_po = scalar(split(/\s+/, $_));
    if($n_po != $n_pred)
    {
        die("Transformace narušily počet tokenů (před $n_pred, po $n_po).\nŘádek před: $pred\nŘádek po  : $_\n");
    }
    print;
}
