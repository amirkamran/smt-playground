#!/usr/bin/perl
# Převede výstup treexového bloku Print::TaggedTokensWithLemma (podobný formát jako CoNLL) do faktorů oddělených svislítky, věta na řádek.
# Copyright © 2011, 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    # Odstranit znak konce řádku.
    s/\r?\n$//;
    # Prázdný řádek odděluje věty.
    if(m/^\s*$/)
    {
        print(join(' ', @tokeny), "\n");
        splice(@tokeny);
    }
    # Neprázdný řádek obsahuje faktory jednoho tokenu.
    else
    {
        # Zakomentovat na řádku případná svislítka.
        s/&/&amp;/g;
        s/\|/&pipe;/g;
        s/</&lt;/g;
        s/>/&gt;/g;
        # Faktory (tvar, lemma, značka) jsou teď oddělené tabulátory. My je chceme oddělit svislítky.
        s/\t/\|/g;
        # Uložit token do paměti.
        push(@tokeny, $_);
    }
}
