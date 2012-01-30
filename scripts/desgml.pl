#!/usr/bin/perl
# Odstraní značky SGML z testovacích dat distribuovaných pro WMT.
# (Je možné, že tohle SGML je stejné jako v NIST MT-Eval, ale neověřoval jsem to.)
# Copyright © 2010 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    # Odstranit zalomení řádku.
    s/\r?\n$//;
    # Zajímají nás pouze řádky se segmenty.
    if(m/<seg\s+id="\d+">(.*?)<\/seg>/i)
    {
        my $seg = $1;
        # Odstranit přebytečné mezery na začátku a na konci segmentu.
        $seg =~ s/^\s+//;
        $seg =~ s/\s+$//;
        # Vytisknout vyčištěný segment.
        print("$seg\n");
    }
}
