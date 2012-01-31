#!/usr/bin/env perl
# Vytvoří Danovy kroky pro Emana.
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use dzsys;

my $steptype = $ARGV[0];
die("Unknown step type $steptype") unless($steptype =~ m/^(augment|data|align|binarize|all)$/);
# Seznam jazykových párů (momentálně pouze tyto: na jedné straně angličtina, na druhé jeden z jazyků čeština, němčina, španělština nebo francouzština)
my @languages = qw(en cs de es fr);
my @pairs;
foreach my $sl (@languages)
{
    foreach my $tl (@languages)
    {
        if($sl eq 'en' && $tl ne 'en' || $sl ne 'en' && $tl eq 'en')
        {
            push(@pairs, [$sl, $tl]);
        }
    }
}
###!!! Dočasně se kvůli testování nového kroku omezíme jen na jeden jazykový pár.
###!!!@pairs = (['en', 'cs']);
# Pro každou kombinaci korpusu, jazyka a faktoru, kterou budeme potřebovat, vytvořit samostatný augmentovací krok.
# Jednotlivé augmenty trvají nevysvětlitelně dlouho a tahle paralelizace by nám měla ulevit.
# Na druhou stranu se obávám, zda Ondrovy zámky ohlídají současné pokusy o vytvoření stejných zdrojových faktorů.
if($steptype =~ m/^(augment|all)$/)
{
    foreach my $language ('cs', 'de', 'es', 'fr')
    {
        my $corpus = "news-commentary-v6.$language-en+europarl-v6.$language-en";
        dzsys::saferun("ACDESC=$corpus/$language+lcstem4 eman init augment --start") or die;
        dzsys::saferun("ACDESC=$corpus/en+lcstem4 eman init augment --start") or die;
        dzsys::saferun("ACDESC=$corpus/$language+stc eman init augment --start") or die;
        dzsys::saferun("ACDESC=$corpus/en+stc eman init augment --start") or die;
    }
    foreach my $year (2008, 2009, 2010, 2011)
    {
        my $corpus = "newstest$year";
        foreach my $language ('cs', 'de', 'en', 'es', 'fr')
        {
            dzsys::saferun("ACDESC=$corpus/$language+stc eman init augment --start") or die;
        }
    }
}
# Pro každý pár vytvořit a spustit vstupní krok dandata, který na jednom místě soustředí odkazy na všechny potřebné korpusy.
if($steptype =~ m/^(data|all)$/)
{
    foreach my $pair (@pairs)
    {
        my ($src, $tgt) = @{$pair};
        dzsys::saferun("SRC=$src TGT=$tgt eman init dandata --start") or die;
    }
}
# Pro každý pár vytvořit a spustit krok danalign, který vyrobí obousměrný alignment.
if($steptype =~ m/^(align|all)$/)
{
    my $gizastep = dzsys::chompticks('eman ls mosesgiza');
    foreach my $pair (@pairs)
    {
        my ($src, $tgt) = @{$pair};
        my $datastep = dzsys::chompticks("eman select t dandata v SRC=$src v TGT=$tgt");
        # Pokud je k dispozici několik zdrojových kroků, vypsat varování a vybrat ten první.
        my @datasteps = split(/\s+/, $datastep);
        if(scalar(@datasteps)==0)
        {
            die("No datastep found for $src-$tgt");
        }
        elsif(scalar(@datasteps)>1)
        {
            my $n = scalar(@datasteps);
            print STDERR ("WARNING: $n datasteps found, using $datasteps[0]\n");
            $datastep = $datasteps[0];
        }
        dzsys::saferun("GIZASTEP=$gizastep DATASTEP=$datastep eman init danalign --start --mem 20g") or die;
    }
}
# Pro každý pár vytvořit a spustit krok binarize, který převede po slovech zarovnaný trénovací korpus do binárního formátu.
if($steptype =~ m/^(binarize|all)$/)
{
    my $joshuastep = dzsys::chompticks('eman ls joshua');
    foreach my $pair (@pairs)
    {
        my ($src, $tgt) = @{$pair};
        my $alignstep = dzsys::chompticks("eman select t danalign v SRC=$src v TGT=$tgt");
        # Pokud je k dispozici několik zdrojových kroků, vypsat varování a vybrat ten první.
        my @alignsteps = split(/\s+/, $alignstep);
        if(scalar(@alignsteps)==0)
        {
            die("No alignstep found for $src-$tgt");
        }
        elsif(scalar(@alignsteps)>1)
        {
            my $n = scalar(@alignsteps);
            print STDERR ("WARNING: $n alignsteps found, using $alignsteps[0]\n");
            $alignstep = $alignsteps[0];
        }
        dzsys::saferun("JOSHUASTEP=$joshuastep ALIGNSTEP=$alignstep eman init binarize --start --mem 31g") or die;
    }
}
