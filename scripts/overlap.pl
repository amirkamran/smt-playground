#!/usr/bin/perl
# Načte postupně dva korpusy a zjistí, kolik vět druhého je obsaženo v prvním.
# Je určeno pro jednojazyčnou polovinu paralelního korpusu, kde každý řádek odpovídá jedné větě (segmentu).
# Copyright © 2009, 2010 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL
# 11.3.2010: Přidána možnost vypisovat čísla vět. Díky tomu půjde získat průnik dvou paralelních korpusů.
# Například máme en-cs a en-de, přičemž anglické strany nejsou totožné, ale dost se překrývají.
# Identifikujeme-li jejich průnik, můžeme získat nový paralelní korpus cs-de.

use utf8;
sub usage
{
    print STDERR ("Užití: overlap.pl text1.txt text2.txt > prunik.txt\n");
    print STDERR ("       overlap.pl -n text1.txt text2.txt > cisla_vet.txt\n");
    print STDERR ("       Druhá varianta vypíše na řádek číslo shodné věty v prvním souboru a číslo ve druhém souboru (číslováno od jedničky).\n");
}

use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long;

GetOptions('n' => \$cisla);
unless(scalar(@ARGV)==2)
{
    usage();
    die("Chybný počet argumentů.\n");
}
$handle = my_open($ARGV[0]);
$i = 0;
while(<$handle>)
{
    $i++;
    # Nepočítáme s tím, že se tatáž věta vyskytne v korpusu opakovaně s různými překlady.
    # Pokud k tomu dojde, ohlásíme pouze první výskyt.
    $hash{$_} = $i unless(exists($hash{$_}));
}
close($handle);
$handle = my_open($ARGV[1]);
$i = 0;
while(<$handle>)
{
    $i++;
    if(exists($hash{$_}))
    {
        if($cisla)
        {
            print("$hash{$_} $i\n");
        }
        else
        {
            print;
        }
        # Zabránit opakovanému ohlášení téhož duplikátu.
        # Zejména když vypisujeme čísla řádků kvůli průniku dvou paralelních korpusů, chceme monotónní výstup.
        delete($hash{$_});
    }
}
close($handle);



#------------------------------------------------------------------------------
# Ondřejovo open si poradí i se zagzipovanými soubory.
#------------------------------------------------------------------------------
sub my_open
{
    my $f = shift;
    die "Not found: $f" if ! -e $f;
    my $opn;
    my $hdl;
    my $ft = `file $f`;
    # file might not recognize some files!
    if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/)
    {
        $opn = "zcat $f |";
    }
    elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/)
    {
        $opn = "bzcat $f |";
    }
    else
    {
        $opn = "$f";
    }
    open $hdl, $opn or die "Can't open '$opn': $!";
    binmode $hdl, ":utf8";
    return $hdl;
}
