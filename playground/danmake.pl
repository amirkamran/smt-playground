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

# OUTCORP=news-europarl-v7.cs-en OUTLANG=cs OUTFACTS=stc eman init augment --start
my $steptype = $ARGV[0];
die("Unknown step type $steptype") unless($steptype =~ m/^(augment|data|align|binarize|extract|tm|lm|zmert|test|all)$/);
# Seznam jazykových párů (momentálně pouze tyto: na jedné straně angličtina, na druhé jeden z jazyků čeština, němčina, španělština nebo francouzština)
my @languages = qw(en cs de es fr);
my @pairs = qw(cs-de cs-en cs-es cs-fr de-cs de-en en-cs en-de en-es en-fr es-cs es-en fr-cs fr-en);
###!!! Dočasně se kvůli testování nového kroku omezíme jen na jeden jazykový pár.
###!!!@pairs = (['en', 'cs']);
# Pro každou kombinaci korpusu, jazyka a faktoru, kterou budeme potřebovat, vytvořit samostatný augmentovací krok.
# Jednotlivé augmenty trvají nevysvětlitelně dlouho a tahle paralelizace by nám měla ulevit.
# Na druhou stranu se obávám, zda Ondrovy zámky ohlídají současné pokusy o vytvoření stejných zdrojových faktorů.
if($steptype =~ m/^(augment|all)$/)
{
    # Odstranit corpman.index a vynutit tak přeindexování.
    # Jinak hrozí, že corpman odmítne zaregistrovat korpus, který jsme už vytvářeli dříve, i když se jeho vytvoření nepovedlo.
    dzsys::saferun("rm -f corpman.index") or die;
    foreach my $language1 ('cs', 'de', 'es', 'fr')
    {
        my @languages2 = ('en');
        push(@languages2, 'cs') unless($language1 eq 'cs');
        foreach my $language2 (@languages2)
        {
            if(0) ###!!!
            {
                my $corpus = "news-europarl-v7.$language1-$language2";
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language1 OUTFACTS=lemma eman init augment --start") or die;
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language2 OUTFACTS=lemma eman init augment --start") or die;
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language1 OUTFACTS=stc eman init augment --start") or die;
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language2 OUTFACTS=stc eman init augment --start") or die;
            }
            if($language1 eq 'es' && $language2 eq 'en')
            {
                my $corpus = "un.$language1-$language2";
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language1 OUTFACTS=lemma eman init augment --start") or die;
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language2 OUTFACTS=lemma eman init augment --start") or die;
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language1 OUTFACTS=stc eman init augment --start") or die;
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language2 OUTFACTS=stc eman init augment --start") or die;
            }
        }
    }
    if(0) ###!!!
    {
        foreach my $year (2008, 2009, 2010, 2011, 2012)
        {
            my $corpus = "newstest$year";
            foreach my $language ('cs', 'de', 'en', 'es', 'fr')
            {
                dzsys::saferun("OUTCORP=$corpus OUTLANG=$language OUTFACTS=stc eman init augment --start") or die;
            }
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
    my $gizastep = dzsys::chompticks('eman select t mosesgiza d');
    my $danalign = 0; # hard switch
    if(!$danalign)
    {
        # Odstranit corpman.index a vynutit tak přeindexování.
        # Jinak hrozí, že corpman odmítne zaregistrovat korpus, který jsme už vytvářeli dříve, i když se jeho vytvoření nepovedlo.
        dzsys::saferun("rm -f corpman.index") or die;
        foreach my $language1 ('cs', 'de', 'es', 'fr')
        {
            my @languages2 = ('en');
            push(@languages2, 'cs') unless($language1 eq 'cs');
            foreach my $language2 (@languages2)
            {
                my $corpus = "news-europarl-v7.$language1-$language2";
                dzsys::saferun("GIZASTEP=$gizastep CORPUS=$corpus SRCALIAUG=$language1+lemma TGTALIAUG=$language2+lemma eman init align --start") or die;
                dzsys::saferun("GIZASTEP=$gizastep CORPUS=$corpus SRCALIAUG=$language2+lemma TGTALIAUG=$language1+lemma eman init align --start") or die;
            }
        }
    }
    else
    {
        foreach my $pair (@pairs)
        {
            my ($src, $tgt) = @{$pair};
            my $datastep = find_step('dandata', "v SRC=$src v TGT=$tgt");
            dzsys::saferun("GIZASTEP=$gizastep DATASTEP=$datastep eman init danalign --start --mem 20g") or die;
        }
    }
}
# Pro každý pár vytvořit a spustit krok binarize, který převede po slovech zarovnaný trénovací korpus do binárního formátu.
if($steptype =~ m/^(binarize|all)$/)
{
    my $joshuastep = dzsys::chompticks('eman ls joshua');
    foreach my $pair (@pairs)
    {
        my ($src, $tgt) = @{$pair};
        my $alignstep = find_step('danalign', "v SRC=$src v TGT=$tgt");
        dzsys::saferun("JOSHUASTEP=$joshuastep ALIGNSTEP=$alignstep eman init binarize --start --mem 31g") or die;
    }
}
# Pro každý pár vytvořit a spustit dev i test krok extract, který vytáhne ze zarovnaného korpusu gramatiku (překladový model) pro daný zdrojový text.
if($steptype =~ m/^(extract|all)$/)
{
    foreach my $pair (@pairs)
    {
        my ($src, $tgt) = @{$pair};
        my $binarizestep = find_step('binarize', "v SRC=$src v TGT=$tgt");
        foreach my $for ('dev', 'test')
        {
            dzsys::saferun("BINARIZESTEP=$binarizestep FOR=$for eman init extract --start") or die;
        }
    }
}
# Pro každý pár vytvořit a spustit krok tm, který natrénuje překladový model Mosese.
if($steptype =~ m/^(tm|all)$/)
{
    my $mosesstep = dzsys::chompticks('eman select t mosesgiza d');
    foreach my $language1 ('cs', 'de', 'es', 'fr')
    {
        my @languages2 = ('en');
        push(@languages2, 'cs') unless($language1 eq 'cs');
        foreach my $language2 (@languages2)
        {
            my $corpus = "news-europarl-v7.$language1-$language2";
            my $alignstep1 = dzsys::chompticks("eman select t align v CORPUS=$corpus v SRCALIAUG=$language1+lemma v TGTALIAUG=$language2+lemma");
            my $alignstep2 = dzsys::chompticks("eman select t align v CORPUS=$corpus v SRCALIAUG=$language2+lemma v TGTALIAUG=$language1+lemma");
            # I do not know what DECODINGSTEPS means. The value "t0-0" has been taken from eman.samples/en-cs-wmt12-small.mert.
            dzsys::saferun("BINARIES=$mosesstep ALISTEP=$alignstep1 SRCAUG=$language1+stc TGTAUG=$language2+stc DECODINGSTEPS=t0-0 eman init tm --start");
            dzsys::saferun("BINARIES=$mosesstep ALISTEP=$alignstep2 SRCAUG=$language2+stc TGTAUG=$language1+stc DECODINGSTEPS=t0-0 eman init tm --start");
        }
    }
}
# Pro každý pár vytvořit a spustit krok lm, který natrénuje jazykový model.
# Poznámka: I když se jazykový model trénuje pouze na cílovém jazyku, model pro páry cs-en a de-en nemusí být stejný,
# protože pro trénování využíváme cílovou stranu paralelního korpusu a ten není pro všechny páry shodný.
if($steptype =~ m/^(lm|all)$/)
{
    my $srilmstep = dzsys::chompticks('eman select t srilm d');
    my $danlm = 0; # hard switch
    if(!$danlm)
    {
        foreach my $language1 ('cs', 'de', 'es', 'fr')
        {
            my @languages2 = ('en');
            push(@languages2, 'cs') unless($language1 eq 'cs');
            foreach my $language2 (@languages2)
            {
                my $corpus = "news-europarl-v7.$language1-$language2";
                dzsys::saferun("SRILMSTEP=$srilmstep CORP=$corpus CORPAUG=$language1+stc ORDER=6 eman init lm --start") or die;
                dzsys::saferun("SRILMSTEP=$srilmstep CORP=$corpus CORPAUG=$language2+stc ORDER=6 eman init lm --start") or die;
            }
        }
    }
    else
    {
        foreach my $pair (@pairs)
        {
            my ($src, $tgt) = @{$pair};
            my $datastep = find_step('dandata', "v SRC=$src v TGT=$tgt");
            dzsys::saferun("SRILMSTEP=$srilmstep DATASTEP=$datastep ORDER=6 eman init danlm --start") or die;
        }
    }
}
# Pro každý pár vytvořit a spustit krok zmert, který vyladí váhy modelu.
if($steptype =~ m/^(zmert|all)$/)
{
    foreach my $pair (@pairs)
    {
        my ($src, $tgt) = @{$pair};
        my $lmstep = find_step('danlm', "v SRC=$src v TGT=$tgt");
        my $tmstep = find_step('extract', "v SRC=$src v TGT=$tgt v FOR=dev");
        dzsys::saferun("LMSTEP=$lmstep EXTRACTSTEP=$tmstep eman init zmert --start") or die;
    }
}
# Pro každý pár vytvořit a spustit krok daneval, který přeloží testovací data a spočítá BLEU skóre.
if($steptype =~ m/^(test|all)$/)
{
    foreach my $pair (@pairs)
    {
        my ($src, $tgt) = @{$pair};
        my $mertstep = find_step('zmert', "v SRC=$src v TGT=$tgt");
        my $tmstep = find_step('extract', "v SRC=$src v TGT=$tgt v FOR=test");
        dzsys::saferun("MERTSTEP=$mertstep EXTRACTSTEP=$tmstep eman init daneval --start") or die;
    }
}



#------------------------------------------------------------------------------
# Najde předcházející krok, na kterém závisíme. Vypíše varování, pokud daným
# kritériím odpovídá několik kroků nebo žádný krok.
#------------------------------------------------------------------------------
sub find_step
{
    my $steptype = shift;
    my $emanselect = shift;
    my $step = dzsys::chompticks("eman select t $steptype $emanselect");
    # Pokud je k dispozici několik zdrojových kroků, vypsat varování a vybrat ten první.
    my @steps = split(/\s+/, $step);
    my $n = scalar(@steps);
    if($n==0)
    {
        my $for = " for $emanselect" if($emanselect);
        die("No $steptype step found$for");
    }
    elsif($n>1)
    {
        print STDERR ("WARNING: $n $steptype steps found, using $steps[0]\n");
        $step = $steps[0];
    }
    return $step;
}
