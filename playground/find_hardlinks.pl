#!/usr/bin/env perl
# Projde všechny složky a jejich podstromy a hledá soubory, jejichž název končí na ".hardlink".
# Předpokládá, že byly spojeny pevným odkazem s jinými soubory, ale toto propojení se porušilo při stěhování struktury složek na jiný disk.
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use find;

$celkova_velikost = 0;
$celkem_odstraneno = 0;
find::go('.', \&zpracovat, \&konec_slozky);
print("Nalezeny hardlinky o celkové velikosti $celkova_velikost B.\n");
print("Z toho odstraněny hardlinky o celkové velikosti $celkem_odstraneno B.\n");
@cile = keys(%links);
$n = scalar(@cile);
print("Ostatní pravděpodobně odkazovaly na celkem $n různých souborů.\n");
foreach my $cil (@cile)
{
    my @zdroje = @{$links{$cil}};
    if($symlinky_v_ramci_hriste{$cil})
    {
        my %zaznam;
        if($cil =~ m-^(.*)/([^/]+)$-)
        {
            $zaznam{cesta} = $1;
            $zaznam{nazev} = $2;
        }
        unshift(@zdroje, \%zaznam);
    }
    my $m = scalar(@zdroje);
    my $velikost = 0;
    foreach my $zdroj (@zdroje)
    {
        $velikost += $zdroj->{velikost};
    }
    print("Na $cil odkazuje $m různých hardlinků o celkové velikosti $velikost.\n");
    if($m>1)
    {
        print("Spojuju je opět dohromady. Všechny kromě prvního mažu a nahrazuju odkazem (skutečným hardlinkem) na první.\n");
        for(my $i = 1; $i<=$#zdroje; $i++)
        {
            my $cil = "$zdroje[0]{cesta}/$zdroje[0]{nazev}";
            my $zdroj = "$zdroje[$i]{cesta}/$zdroje[$i]{nazev}";
            # Poslední kontrola.
            unless(-f $cil && !-l $cil && -f $zdroj && !-l $zdroj)
            {
                die("$cil nebo $zdroj nejsou soubory.");
            }
            print("unlink($zdroj)\n");
            unlink($zdroj) or die("Nelze odstranit $zdroj: $!");
            print("link($cil, $zdroj)\n");
            link($cil, $zdroj) or die("Nelze spojit $cil a $zdroj: $!");
        }
    }
}

sub zpracovat
{
    my $cesta = shift;
    my $objekt = shift;
    my $druh = shift;
    if($druh eq 'drx')
    {
#        print("$cesta/$objekt\n");
    }
    else
    {
        my %zaznam =
        (
            'cesta' => $cesta,
            'nazev' => $objekt,
            'druh' => $druh,
            'velikost' => -s "$cesta/$objekt"
        );
        push(@{$obsah{$cesta}}, \%zaznam);
    }
    return $druh eq 'drx';
}

sub konec_slozky
{
    my $cesta = shift;
    my @obsah = @{$obsah{$cesta}};
#    printf("Složka $cesta obsahuje %d souborů.\n", scalar(@obsah));
    my @hardlinky = grep {$_->{nazev} =~ m/\.hardlink$/} (@obsah);
    foreach my $hl (@hardlinky)
    {
        print("Nalezen hardlink $cesta/$hl->{nazev}\n");
        # Je ve stejné složce softlink nebo soubor stejného jména?
        my $dvojce_nazev = $hl->{nazev};
        $dvojce_nazev =~ s/\.hardlink$//;
        my @dvojcata = grep {$_->{nazev} eq $dvojce_nazev} (@obsah);
        if(@dvojcata)
        {
            my $dvojce = $dvojcata[0];
            print("Nalezeno dvojče $cesta/$dvojce->{nazev}\n");
            my $stejne = $hl->{velikost}==$dvojce->{velikost} ? ' ... STEJNÉ!' : '';
            print("Velikosti souborů: hl = $hl->{velikost}, dvojče = $dvojce->{velikost}$stejne\n");
            if($hl->{velikost}==$dvojce->{velikost})
            {
                if($dvojce->{druh} =~ m/l$/)
                {
                    my $cil = readlink("$cesta/$dvojce->{nazev}");
                    # Jestliže symbolický odkaz vede na staré hřiště, nemáme náhodou tentýž krok i na novém hřišti?
                    if($cil =~ m-^/ha/work/people/zeman/statmt/playground/(.*)$- && -f $1 && !-l $1)
                    {
                        my $novy_cil = "/net/cluster/TMP/zeman/new_playground/$1";
                        print("Dvojče je symbolický odkaz na $cil, který máme i na novém hřišti!\n");
                        unlink("$cesta/$dvojce->{nazev}") or die("Nelze odstranit symbolický odkaz $cesta/$dvojce->{nazev}: $!");
                        symlink($novy_cil, "$cesta/$dvojce->{nazev}") or die("Nelze vytvořit symbolický odkaz $cesta/$dvojce->{nazev} -> $novy_cil: $!\n");
                        $symlinky_v_ramci_hriste{$novy_cil}++;
                        $cil = $novy_cil;
                    }
                    elsif($cil =~ m-^/net/cluster/TMP/zeman/new_playground/(.*)$- && -f $1 && !-l $1 ||
                          $cil =~ m-^[^/]- && -f $cil && !-l $cil)
                    {
                        print("Dvojče je symbolický odkaz na $cil, tj. uvnitř nového hřiště!\n");
                        $symlinky_v_ramci_hriste{$cil}++;
                    }
                    else
                    {
                        print("Dvojče je symbolický odkaz na $cil\n");
                    }
                    push(@{$links{$cil}}, $hl);
                }
                else
                {
                    print("Dvojče není symbolický odkaz, hardlink odstraníme bez náhrady.\n");
                    unlink("$cesta/$hl->{nazev}") or print("Nepodařilo se odstranit hardlink: $!\n");
                    $celkem_odstraneno += $hl->{velikost}; ###!!! Chybně započítáváme i hardlinky, jejichž odstranění se nepodařilo.
                }
            }
        }
        $celkova_velikost += $hl->{velikost};
    }
}
