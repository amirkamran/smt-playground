#!/usr/bin/perl
# Zkontroluje konzistenci výstupu Gizy++.
# Funguje jen v Linuxu, volá jeho nástroje.
# Copyright © 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

sub usage
{
    print STDERR ("Užití: check_alignment.pl source target alignment\n");
}

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
# Cesta k Danovým perlovým knihovnám.
use lib '/home/zeman/lib';
use dzsys;

if(scalar(@ARGV)!=3)
{
    usage();
    die();
}
$source_file = $ARGV[0];
$target_file = $ARGV[1];
$alignment_file = $ARGV[2];
# Všechny tři soubory musí mít stejný počet řádků. Řádek odpovídá větě či segmentu.
print("Kontrolujeme, zda mají všechny tři soubory stejný počet řádků (vět, segmentů).\n");
$wc_source = $source_file =~ m/\.gz$/ ? `gunzip -c $source_file | wc -l` : `wc -l $source_file`; $wc_source =~ s/\s+$//s;
$wc_target = $target_file =~ m/\.gz$/ ? `gunzip -c $target_file | wc -l` : `wc -l $target_file`; $wc_target =~ s/\s+$//s;
$wc_alignment = $alignment_file =~ m/\.gz$/ ? `gunzip -c $alignment_file | wc -l` : `wc -l $alignment_file`; $wc_alignment =~ s/\s+$//s;
printf("  %9d $source_file\n", $wc_source);
printf("  %9d $target_file\n", $wc_target);
printf("  %9d $alignment_file\n", $wc_alignment);
if($wc_source != $wc_target || $wc_source != $wc_alignment)
{
    die("Počet řádků ve zdrojovém textu, cílovém textu a párovacím souboru není stejný.\n");
}
# Soubor s párováním obsahuje číselné odkazy na slova ve zdrojovém a cílovém textu.
# Tyto odkazy nesmí odkazovat doprázdna, tj. musí mít hodnotu mezi 1 a číslem posledního tokenu ve větě.
print("Kontrolujeme, že indexy z párovacího souboru odkazují na existující slova.\n");
# Zkontrolovat, že indexy z párovacího souboru odkazují na existující slova.
$hsrc = dzsys::gopen($source_file);
$htgt = dzsys::gopen($target_file);
$hali = dzsys::gopen($alignment_file);
$i_line = 0;
$n_dlouhych = 0;
while(!eof($hsrc) && !eof($htgt) && !eof($hali))
{
    my $lsrc = <$hsrc>;
    my $ltgt = <$htgt>;
    my $lali = <$hali>;
    $i_line++;
    # Odstranit konce řádků.
    $lsrc =~ s/\r?\n$//;
    $ltgt =~ s/\r?\n$//;
    $lali =~ s/\r?\n$//;
    # Rozebrat na tokeny.
    my @toksrc = split(/\s+/, $lsrc);
    my @toktgt = split(/\s+/, $ltgt);
    my $nsrc = scalar(@toksrc);
    my $ntgt = scalar(@toktgt);
    # Rozebrat párování.
    my @ali = map {my @pair = split(/-/, $_); \@pair;} (split(/\s+/, $lali));
    # Zkontrolovat párování.
    for(my $i = 0; $i<=$#ali; $i++)
    {
        # Pár musí obsahovat právě dvě čísla (zatím je to obecné pole).
        if(scalar(@{$ali[$i]})!=2 || $ali[$i][0] !~ m/^\d+$/ || $ali[$i][1] !~ m/^\d+$/)
        {
            printf STDERR ("Řádek $i_line, token %d (obojí číslováno od jedničky):\n", $i+1);
            print STDERR ("$lali\n");
            die("Token v párovacím souboru musí obsahovat právě dvě přirozená čísla oddělená pomlčkou.\n");
        }
        # Levé číslo musí být platný odkaz do zdrojového souboru.
        if($ali[$i][0]>=$nsrc)
        {
            printf STDERR ("Řádek $i_line, token %d (obojí číslováno od jedničky):\n", $i+1);
            print STDERR ("$lali\n");
            print STDERR ("Zdrojová věta má $nsrc tokenů:\n");
            print STDERR ("$lsrc\n");
            die("Levé číslo v párovacím tokenu musí být platný odkaz do zdrojové věty (slova jsou číslována od nuly).\n");
        }
        # Pravé číslo musí být platný odkaz do cílového souboru.
        if($ali[$i][1]>=$ntgt)
        {
            printf STDERR ("Řádek $i_line, token %d (obojí číslováno od jedničky):\n", $i+1);
            print STDERR ("$lali\n");
            print STDERR ("Cílová věta má $ntgt tokenů:\n");
            print STDERR ("$ltgt\n");
            die("Pravé číslo v párovacím tokenu musí být platný odkaz do cílové věty (slova jsou číslována od nuly).\n");
        }
    }
    # Varovat před dlouhými větami.
    if($nsrc>=100 || $ntgt>=100)
    {
        print STDERR ("Varování: řádek $i_line, zdrojových tokenů $nsrc, cílových tokenů $ntgt.\n");
        $n_dlouhych++;
        $max_tokenu = $nsrc if($nsrc>$max_tokenu);
        $max_tokenu = $ntgt if($ntgt>$max_tokenu);
    }
}
close($hsrc);
close($htgt);
close($hali);
print("Celkem nalezeno $n_dlouhych dlouhých vět. Maximální počet tokenů byl $max_tokenu.\n");
print("OK\n");
