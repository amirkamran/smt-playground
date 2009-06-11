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
$wc_source = `wc -l $source_file`; $wc_source =~ s/\s+$//s;
$wc_target = `wc -l $target_file`; $wc_target =~ s/\s+$//s;
$wc_alignment = `wc -l $alignment_file`; $wc_alignment =~ s/\s+$//s;
printf("  %9d $source_file\n", $wc_source);
printf("  %9d $target_file\n", $wc_target);
printf("  %9d $alignment_file\n", $wc_alignment);
if($wc_source != $wc_target || $wc_source != $wc_alignment)
{
    die("Počet řádků ve zdrojovém textu, cílovém textu a párovacím souboru není stejný.\n");
}
# Soubor s párováním obsahuje číselné odkazy na slova ve zdrojovém a cílovém textu.
# Tyto odkazy nesmí odkazovat doprázdna, tj. musí mít hodnotu mezi 1 a číslem posledního tokenu ve větě.
print("Ještě bychom měli zkontrolovat, že indexy z párovacího souboru odkazují na existující slova, tato kontrola ale zatím není implementovaná.\n");
