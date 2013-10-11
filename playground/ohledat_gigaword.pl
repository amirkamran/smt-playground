#!/usr/bin/env perl

use utf8;
use open ':utf8';
binmode(STDOUT, ':utf8');
use dzsys;

$cesta = "/home/zeman/projekty/statmt/playground/s.tag.867ec3d8.20120627-2116/chunks";
$clrun = "001-cluster-run-LJX_D/output";
opendir(DIR, $cesta) or die("Cannot open folder $cesta: $!");
@vstupy = grep {m/\.txt\.gz$/} (readdir(DIR));
closedir(DIR);
$n_vstup = scalar(@vstupy);
print("Nalezeno celkem $n_vstup vstupních souborů.\n");
opendir(DIR, "$cesta/$clrun") or die("Cannot open folder $cesta/$clrun: $!");
@vystupy = grep {m/\d\.stdout$/} (readdir(DIR));
closedir(DIR);
$n_vystup = scalar(@vystupy);
print("Nalezeno celkem $n_vystup výstupních souborů.\n");
$n_chybi = $n_vstup-$n_vystup;
# Názvy výstupních souborů mají tento tvar: job100-doc0117900.stdout
# A pozor, nejsou to jediné soubory v dané složce, jejichž název končí na stdout: job100-loading.stdout
foreach my $vystup (@vystupy)
{
    if($vystup =~ m/^job\d+-doc(\d+)\.stdout$/)
    {
        # Treex čísluje výstupní soubory od jedničky, ne od nuly.
        my $i = $1-1;
        $mapa_vystupu[$i] = $vystup;
    }
    else
    {
        die("Neznámý název výstupního souboru '$vystup'.");
    }
}
if($n_chybi>0)
{
    print("Chybí $n_chybi výstupních souborů.\n");
    # Zjistit, které to jsou.
    # Názvy vstupních souborů mají tento tvar: 117905.txt.gz
    foreach my $vstup (@vstupy)
    {
        if($vstup =~ m/^(\d+)\.txt\.gz$/)
        {
            $mapa_vstupu[$1] = $vstup;
        }
        else
        {
            die("Neznámý název vstupního souboru '$vstup'.");
        }
    }
    print("Chybějící výstupní dokumenty (.stdout):\n");
    for(my $i = 0; $i<=$#mapa_vstupu; $i++)
    {
        if(exists($mapa_vstupu[$i]) && !exists($mapa_vystupu[$i]))
        {
            # Nevím o způsobu, jak z výstupů na disku zjistit, která úloha byla zodpovědná za konkrétní chybějící výstup.
            # Využijeme tedy znalost toho, jak Treex dokumenty rozděluje. Máme 100 úloh a 117906 dokumentů.
            # Úloha 001 má na starosti dokumenty 1, 101, 201, ..., 117801, 117901
            # Úloha 100 má na starosti dokumenty 100, 200, 300, ..., 117800, 117900
            # Nikdo nemá na starosti dokument 0. Zřejmě to znamená, že Treex dokumenty přečíslovává.
            # Vstupní dokumenty jsou pojmenované (očíslované) 000000.txt.gz až 117905.txt.gz.
            # Výstupní dokumenty jsou pojmenované job001-doc0000001.stdout až job006-doc0117906.stdout.
            my $nazev = sprintf("job%03d-doc%07d", ($i+1)%100, $i+1);
            #push(@chybejici_dokumenty, $nazev);
            push(@chybejici_dokumenty, $i);
        }
    }
    print(join(' ', @chybejici_dokumenty), "\n");
    # Pokusit se chybějící dokumenty zpracovat znova, bez clusteru a každý zvlášť.
    print("Pokusíme se chybějící dokumenty vyrobit.\n");
    foreach my $i (@chybejici_dokumenty)
    {
        my $vstup = sprintf("$cesta/%06d.txt.gz", $i);
        my $mezivystup = sprintf("$cesta/$clrun/job999-doc%07d.0.txt", $i+1);
        my $vystup = sprintf("$cesta/$clrun/job999-doc%07d.stdout", $i+1);
        dzsys::saferun("treex -Len Read::Sentences from=$vstup W2A::TokenizeOnWhitespace W2A::EN::TagMorce W2A::EN::FixTags W2A::EN::Lemmatize Print::TaggedTokensWithLemma --no-save > $mezivystup") or die;
        dzsys::saferun("/home/zeman/projekty/statmt/scripts/put_sentence_on_one_line.pl < $mezivystup > $vystup") or die;
    }
}
else # žádný výstupní soubor nechybí, snad tedy také obsahují to, co mají
{
    # Slepit všechny výstupní soubory do jednoho.
    # Systémový cat má být zřetelně rychlejší než tahle perlová simulace, jenže my chceme výsledek ještě gzipovat.
    # A udělat něco jako "cat *.stdout | gzip -c" je riskantní, jednak obtížně zkontrolujeme výběr a pořadí souborů,
    # jednak pravděpodobně přeteče maximální povolená délka příkazového řádku.
    # Ostatně, tohle je stejně jednorázová operace.
    print("Výstupní soubory jsou zřejmě kompletní, slepíme je do $cesta/$clrun/vystup.txt.gz.\n");
    open(OUT, "| gzip -c > $cesta/$clrun/vystup.txt.gz") or die("Nelze psát $cesta/$clrun/vystup.txt.gz: $!");
    for(my $i = 0; $i<=$#mapa_vystupu; $i++)
    {
        if(exists($mapa_vystupu[$i]))
        {
            print("Čte se $mapa_vystupu[$i]...\n");
            open(IN, "$cesta/$clrun/$mapa_vystupu[$i]") or die("Nelze číst $cesta/$clrun/$mapa_vystupu[$i]: $!");
            while(<IN>)
            {
                print OUT;
            }
            close(IN);
        }
    }
    close(OUT);
    print("Soubor $cesta/$clrun/vystup.txt.gz byl uložen.\n");
}

