#!/usr/bin/env perl
# Získá paralelní korpus xx-cs jako průnik korpusů xx-en a cs-en.
# Příslušnost k průniku se posuzuje porovnáním celé věty v daném jazyce. Věty se hashují, jejich pořadí na výstupu není definováno.
# Copyright © 2012-2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
sub usage
{
    print STDERR ("Příklad užití: intersect.pl europarl-v7 de\n");
    print STDERR ("\tČte  europarl-v7.cs-en.cs.gz a .en.gz.\n");
    print STDERR ("\tČte  europarl-v7.de-en.de.gz a .en.gz.\n");
    print STDERR ("\tPíše europarl-v7.de-cs/de.gz a /cs.gz.\n");
}



use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;
use Carp;
use dzsys;
use cas;
use cluster;

GetOptions('akce=s' => \$nazev_akce);

confess('$STATMT is not defined') unless($ENV{STATMT});
my $smtscrdir = $ENV{STATMT}.'/scripts';
if(scalar(@ARGV)<2)
{
    usage();
    confess("Očekávány 2 argumenty: název korpusu a kód třetího jazyka");
}
my $korpus = $ARGV[0];
my $jazyk = $ARGV[1];
my $path = '/net/data/wmt/training';
ziskat_prunik_korpusu("$path/$korpus.$jazyk-en", "$path/$korpus.cs-en", "$path/$korpus.$jazyk-cs", $jazyk, 'en', 'cs');



#------------------------------------------------------------------------------
# Najde průnik dvou paralelních korpusů pro celkem tři jazyky, např. anglo-
# německého s anglo-českým. Výsledkem je nový německo-český korpus. Cesty
# ke vstupním korpusům musejí být buď absolutní, nebo relativní vzhledem
# k cílové složce.
#------------------------------------------------------------------------------
sub ziskat_prunik_korpusu
{
    my $korpus1_cesta = shift;
    my $korpus2_cesta = shift;
    my $cil_cesta = shift;
    my $jazyk1 = shift;
    my $jazyk12 = shift; # jazyk společný oběma korpusům
    my $jazyk2 = shift;
    dzsys::saferun("mkdir -p $cil_cesta") or confess();
    chdir($cil_cesta) or confess("Nelze vstoupit do $cil_cesta: $!");
    dzsys::saferun("$smtscrdir/overlap.pl -n $korpus1_cesta.$jazyk12.gz $korpus2_cesta.$jazyk12.gz > intersection_line_numbers.txt") or confess();
    dzsys::saferun("$smtscrdir/filter-corpus.pl -l < intersection_line_numbers.txt $korpus1_cesta.$jazyk1.gz $jazyk1.gz") or confess();
    dzsys::saferun("$smtscrdir/filter-corpus.pl -r < intersection_line_numbers.txt $korpus2_cesta.$jazyk2.gz $jazyk2.gz") or confess();
    my $n_radku_1 = dzsys::chompticks("gunzip -c $jazyk1.gz | wc -l");
    my $n_radku_2 = dzsys::chompticks("gunzip -c $jazyk2.gz | wc -l");
    confess("$jazyk1.gz má $n_radku_1 řádků, ale $jazyk2.gz má $n_radku_2 řádků") if($n_radku_1 != $n_radku_2);
    dzsys::saferun("echo $n_radku_1 > LINECOUNT");
}

