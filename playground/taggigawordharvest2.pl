#!/usr/bin/env perl
# Projde výstup nového značkování anglického Gigawordu (27.3.2013), zkontroluje, že je tam všechno, a vyrobí výstupní korpus.
# Copyright © 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# Když už víme, co nedoběhlo, pokusit se to opravit.
if($ARGV[0] eq 'opravit')
{
#    znova_oznackovat(84723, 102494); # Tohle už je opraveno, ale přehlédl jsem, že 99999 sice existuje, ale je prázdný.
    znova_oznackovat(99999);
    exit;
}
# Když už budeme všechny výstupní soubory číst, mohli bychom je rovnou protlačit závěrečným filtrem a vyrobit z nich faktorizovaný korpus.
$cesta_krok = "$ENV{STATMT}/playground/s.tag.9bb68488.20130322-2258";
open(FAKTOR, "| /home/zeman/projekty/statmt/scripts/put_sentence_on_one_line.pl | gzip -c > $cesta_krok/tgharvest.txt.gz") or die("Nelze otevřít výstupní filtr: $!");
# Následuje starší kód, který hledá, co nedoběhlo, nyní rozšířený o kopírování načtených dat do výstupního filtru.
$cesta = "$cesta_krok/chunks/001-cluster-run-U674e/output";
$ndoc = 117906;
chdir($cesta) or die("Nelze přepnout do složky $cesta: $!");
for(my $i = 1; $i<=$ndoc; $i++)
{
    my $soubor = sprintf("doc%07d.stdout", $i);
    if($i % 1000)
    {
        print STDERR ('.');
    }
    else
    {
        print STDERR ("($i)");
    }
    open(SOUBOR, $soubor) or print STDERR ("Nelze otevřít $soubor: $!\n");
    my $nvet = 0;
    while(<SOUBOR>)
    {
        print FAKTOR;
        # Prázdný řádek znamená konec věty.
        # Vyskytuje se i za poslední větou v souboru.
        if( m/^\s*$/ )
        {
            $nvet++;
        }
    }
    close(SOUBOR);
    # Méně než 1000 vět znamená buď poslední dokument, nebo poškozený dokument.
    if($i<$ndoc && $nvet!=1000)
    {
        print STDERR ("Dokument $soubor obsahuje pouze $nvet vět.\n");
    }
}
print STDERR ("\n");
close(FAKTOR);



#------------------------------------------------------------------------------
# Spustí neparalelní lokální Treex s cílem znova zpracovat soubor, který mezi
# paralelními výstupy chybí.
#------------------------------------------------------------------------------
sub znova_oznackovat
{
    while(1)
    {
        # Číslo dokumentu z intervalu <1; $ndoc> (takto jsou číslovány výstupní soubory, zatímco vstupní jsou číslovány od nuly).
        my $i = shift;
        return if(!defined($i));
        my $cesta_koren = "$ENV{STATMT}/playground/s.tag.9bb68488.20130322-2258/chunks";
        my $cesta_vstup = sprintf("$cesta_koren/%06d.txt.gz", $i-1);
        my $cesta_vystup = sprintf("$cesta_koren/001-cluster-run-U674e/output/doc%07d.stdout", $i);
        print STDERR ("Bude se znova značkovat < $cesta_vstup > $cesta_vystup.\n");
        # Zazálohovat původní výstup, pokud existuje a pokud jsme ho ještě nezálohovali.
        if(-f $cesta_vystup && !-f "$cesta_vystup.bak")
        {
            print STDERR ("Zálohuje se $cesta_vystup...\n");
            system("cp $cesta_vystup $cesta_vystup.bak");
        }
        # Spustit Treex, který vyrobí nový výstupní soubor.
        chdir($cesta_koren) or die("Nelze přejít do složky $cesta_koren: $!");
        system("treex -Len Read::Sentences from=$cesta_vstup W2A::TokenizeOnWhitespace W2A::EN::TagFeaturama W2A::EN::FixTags W2A::EN::Lemmatize Print::TaggedTokensWithLemma --no-save > $cesta_vystup");
    }
}

