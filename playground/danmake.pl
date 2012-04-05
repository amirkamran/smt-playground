#!/usr/bin/env perl
# Vytvoří Danovy kroky pro Emana.
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;
use Carp;
use dzsys;

# @ARGV obsahuje regulární výrazy pro výběr zúčastněných korpusů. Ten může být dále omezen volbami -first a -last.
GetOptions
(
    'type|action=s' => \$steptype,
    'first=s' => \$firstcorpus, # useful when previous run failed but some of the jobs were submitted successfully
    'last=s' => \$lastcorpus,
    'lm=s' => \$lmcorpus, # for steps model, mert etc.: use this language model instead of the default; e.g. '-lm news.2009' will select news.2009.de for experiments to German
              # several monolingual corpora delimited by commas (e.g. -lm news.2009,news.2010) => everything will be called separately for each of them
    'morph|morf' => \$use_morphemes # use language code xx~morf instead of xx
);

die("Unknown step type $steptype") unless($steptype =~ m/^(augment|augmentbasic|combine|morfcorpus|data|align|morfalign|binarize|extract|tm|combinetm|lm|model|mert|zmert|translate|evaluator|test|all)$/);
# Seznam jazykových párů (momentálně pouze tyto: na jedné straně angličtina, na druhé jeden z jazyků čeština, němčina, španělština nebo francouzština)
my @languages = qw(en cs de es fr);
my @pairs = qw(cs-de cs-en cs-es cs-fr de-cs de-en en-cs en-de en-es en-fr es-cs es-en fr-cs fr-en);
# Vytvořit si seznam paralelních trénovacích korpusů. Budeme z něj vycházet při zakládání jednotlivých kroků.
my @parallel_training_corpora;
foreach my $language1 ('cs', 'de', 'es', 'fr')
{
    my @languages2 = ('en');
    push(@languages2, 'cs') unless($language1 eq 'cs');
    foreach my $language2 (@languages2)
    {
        push(@parallel_training_corpora, "news-europarl-v7.$language1-$language2");
        if($language1 =~ m/^(es|fr)$/ && $language2 eq 'en')
        {
            push(@parallel_training_corpora, "un.$language1-$language2");
        }
    }
}
# Vytvořit si seznam jednojazyčných trénovacích korpusů. Budeme z něj vycházet při přípravě jazykových modelů.
my @mono_training_corpora;
foreach my $language ('cs', 'de', 'en', 'es', 'fr')
{
    # K paralelním korpusům news-commentary a europarl existují jednojazyčná sjednocení.
    # Např. europarl-v7.cs/cs.gz by mělo být stejné nebo větší než europarl-v7.cs-en/cs.gz:
    # europarl-v7.cs     668595
    # europarl-v7.cs-en  646605
    # europarl-v7.de    2176537
    # europarl-v7.de-en 1920209
    # europarl-v7.en    2218201
    # europarl-v7.es    2123835
    # europarl-v7.es-en 1965734
    # europarl-v7.fr    2190579
    # europarl-v7.fr-en 2007723
    push(@mono_training_corpora, "news-commentary-v7.$language");
    push(@mono_training_corpora, "europarl-v7.$language");
    my $news_euro = "news-commentary-v7.$language+europarl-v7.$language";
    push(@mono_training_corpora, $news_euro);
    foreach my $year (2007..2011)
    {
        push(@mono_training_corpora, "news.$year.$language");
        push(@mono_training_corpora, "$news_euro+news.$year.$language");
    }
    my $news_all = "news.2007.$language+news.2008.$language+news.2009.$language+news.2010.$language+news.2011.$language";
    push(@mono_training_corpora, $news_all);
    push(@mono_training_corpora, "$news_euro+$news_all");
    if($language =~ m/^(en|es|fr)$/)
    {
        push(@mono_training_corpora, "gigaword.$language");
    }
}
# Omezit se na korpusy, o které si uživatel řekl, pokud si řekl.
if($firstcorpus || $lastcorpus)
{
    my @corpora;
    my $on = 0;
    foreach my $corpus (@parallel_training_corpora)
    {
        $on = 1 if($corpus eq $firstcorpus);
        push(@corpora, $corpus) if($on);
        $on = 0 if($corpus eq $lastcorpus);
    }
    @parallel_training_corpora = @corpora;
    splice(@corpora);
    foreach my $corpus (@mono_training_corpora)
    {
        $on = 1 if($corpus eq $firstcorpus);
        push(@corpora, $corpus) if($on);
        $on = 0 if($corpus eq $lastcorpus);
    }
    @mono_training_corpora = @corpora;
}
if(@ARGV)
{
    # Argumenty jsou regulární výrazy pro výběr korpusů nebo zkratkové kódy.
    # Přepsat zkratkové kódy na regulární výrazy.
    my @vyber = map
    {
        my $vysledek;
        if($_ eq 'news.all')
        {
            $vysledek = 'news\.2007\.([a-z]+)\+news\.2008\.\1\+news\.2009\.\1\+news\.2010\.\1\+news\.2011\.\1';
        }
        elsif($_ eq 'ne+news.all')
        {
            $vysledek = 'news-commentary-v7\.([a-z]+)\+europarl-v7\.\1\+news\.2007\.\1\+news\.2008\.\1\+news\.2009\.\1\+news\.2010\.\1\+news\.2011\.\1';
        }
        else
        {
            $vysledek = $_;
        }
        $vysledek;
    }
    (@ARGV);
    @parallel_training_corpora = grep {my $corpus = $_; grep {$corpus =~ $_} (@vyber)} (@parallel_training_corpora);
    @mono_training_corpora = grep {my $corpus = $_; grep {$corpus =~ $_} (@vyber)} (@mono_training_corpora);
}
# $lmcorpus určuje nezávislý jednojazyčný korpus, který se má přibalit ke krokům model, mert, translate, evaluator apod.
# Pokud uživatel zadal více takových korpusů, vytvořit stejnou sadu kroků pro každý z nich.
if($lmcorpus && $lmcorpus =~ m/,/)
{
    @lmcorpora = split(/,/, $lmcorpus);
}
else
{
    @lmcorpora = ($lmcorpus);
}
# Pozor, stále chceme, aby $lmcorpus byl globální proměnná, takže žádné my!
foreach $lmcorpus (@lmcorpora)
{
    # Pro každou kombinaci korpusu, jazyka a faktoru, kterou budeme potřebovat, vytvořit samostatný augmentovací krok.
    # Jednotlivé augmenty trvají nevysvětlitelně dlouho a tahle paralelizace by nám měla ulevit.
    # Na druhou stranu se obávám, zda Ondrovy zámky ohlídají současné pokusy o vytvoření stejných zdrojových faktorů.
    if($steptype =~ m/^(augment|all)$/)
    {
        # Odstranit corpman.index a vynutit tak přeindexování.
        # Jinak hrozí, že corpman odmítne zaregistrovat korpus, který jsme už vytvářeli dříve, i když se jeho vytvoření nepovedlo.
        dzsys::saferun("rm -f corpman.index") or die;
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            dzsys::saferun("OUTCORP=$corpus OUTLANG=$language1 OUTFACTS=lemma eman init augment --start") or die;
            dzsys::saferun("OUTCORP=$corpus OUTLANG=$language2 OUTFACTS=lemma eman init augment --start") or die;
            dzsys::saferun("OUTCORP=$corpus OUTLANG=$language1 OUTFACTS=stc eman init augment --start") or die;
            dzsys::saferun("OUTCORP=$corpus OUTLANG=$language2 OUTFACTS=stc eman init augment --start") or die;
        }
        # A teď ještě jednojazyčná data na trénování jazykových modelů.
        foreach my $corpus (@mono_training_corpora)
        {
            my $language = get_language_code($corpus);
            dzsys::saferun("OUTCORP=$corpus OUTLANG=$language OUTFACTS=stc eman init augment --start") or die;
        }
    }
    # Corpman mě permanentně buzeruje, že nemám pro své korpusy dostupný faktor form, protože jsem převzal přímo stc.
    # Pojďme tedy jednorázově vyrobit základní korpusy s faktory form+lemma+tag pro paralelní korpusy
    # news-commentary-v7 a europarl-v7, které jinak samostatně ani nemám na repertoáru.
    if($steptype eq 'augmentbasic')
    {
        # Seznam neorientovaných párů kvůli identifikaci jednotlivých po dvou paralelních podmnožin.
        # Poznámka: Tyto základní korpusy nemáme k dispozici pro páry de-cs, es-cs a fr-cs, pro ty už jsem rovnou vyráběl spojené korpusy news-commentary-europarl-v7.
        my @pairs = ('cs-en', 'de-en', 'es-en', 'fr-en');
        foreach my $pair (@pairs)
        {
            my ($language1, $language2) = get_language_codes("korpus.$pair");
            dzsys::saferun("OUTCORP=news-commentary-v7.$pair OUTLANG=$language1 OUTFACTS=form+lemma+tag eman init augment --start") or die;
            dzsys::saferun("OUTCORP=news-commentary-v7.$pair OUTLANG=$language2 OUTFACTS=form+lemma+tag eman init augment --start") or die;
            dzsys::saferun("OUTCORP=europarl-v7.$pair        OUTLANG=$language1 OUTFACTS=form+lemma+tag eman init augment --start") or die;
            dzsys::saferun("OUTCORP=europarl-v7.$pair        OUTLANG=$language2 OUTFACTS=form+lemma+tag eman init augment --start") or die;
        }
    }
    # Výroba kombinovaných paralelních korpusů.
    if($steptype eq 'combine')
    {
        foreach my $language ('es', 'fr')
        {
            # Bohužel máme nestejně připravené zdroje. Textová data se musí kombinovat ze tří korpusů,
            # zatímco zarovnání máme už nachystané pro kombinaci prvních dvou dohromady.
            # Nejdříve tedy zkombinovat první dva, počkat, až budou hotové, řádek zakomentovat a odkomentovat ty dva pod ním.
            #combine_corpora("news-europarl-v7.$language-en", "news-commentary-v7.$language-en", "europarl-v7.$language-en", $language, 'en');
            combine_corpora("news-euro-un.$language-en", "news-europarl-v7.$language-en", "un.$language-en", $language, 'en');
            combine_alignments("news-euro-un.$language-en", "news-europarl-v7.$language-en", "un.$language-en", $language, 'en');
        }
    }
    # Pro každou kombinaci korpusu a jazyka a faktoru, vytvořit krok, který segmentuje faktor stc na morfémy.
    if($steptype =~ m/^(morfcorpus|all)$/)
    {
        my $morfessorstep = find_step('morfessor', 'd');
        # Odstranit corpman.index a vynutit tak přeindexování.
        # Jinak hrozí, že corpman odmítne zaregistrovat korpus, který jsme už vytvářeli dříve, i když se jeho vytvoření nepovedlo.
        dzsys::saferun("rm -f corpman.index") or die;
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            dzsys::saferun("MORFESSORSTEP=$morfessorstep CORP=$corpus LANG=$language1 FACT=stc eman init morfcorpus --start") or die;
            dzsys::saferun("MORFESSORSTEP=$morfessorstep CORP=$corpus LANG=$language2 FACT=stc eman init morfcorpus --start") or die;
        }
        # A teď ještě jednojazyčná data na trénování jazykových modelů.
        foreach my $corpus (@mono_training_corpora)
        {
            my $language = get_language_code($corpus);
            dzsys::saferun("MORFESSORSTEP=$morfessorstep CORP=$corpus LANG=$language FACT=stc eman init morfcorpus --start") or die;
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
            foreach my $corpus (@parallel_training_corpora)
            {
                my ($language1, $language2) = get_language_codes($corpus);
                # Gizawrapper vytváří nemalou pomocnou složku v /mnt/h. Měli bychom požadovat alespoň 15 GB volného místa,
                # i když už jsem viděl korpus, na který nestačilo ani 50 GB.
                my $disk = '15g';
                dzsys::saferun("GIZASTEP=$gizastep CORPUS=$corpus SRCALIAUG=$language1+lemma TGTALIAUG=$language2+lemma eman init align --start --disk $disk") or die;
                dzsys::saferun("GIZASTEP=$gizastep CORPUS=$corpus SRCALIAUG=$language2+lemma TGTALIAUG=$language1+lemma eman init align --start --disk $disk") or die;
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
    # Pro každý pár vytvořit a spustit krok align, který vyrobí obousměrný alignment morfémů.
    if($steptype =~ m/^(morfalign|all)$/)
    {
        my $gizastep = dzsys::chompticks('eman select t mosesgiza d');
        # Odstranit corpman.index a vynutit tak přeindexování.
        # Jinak hrozí, že corpman odmítne zaregistrovat korpus, který jsme už vytvářeli dříve, i když se jeho vytvoření nepovedlo.
        dzsys::saferun("rm -f corpman.index") or die;
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            # Gizawrapper vytváří nemalou pomocnou složku v /mnt/h, takže musíme požadovat i místo na disku (50 GB je někdy málo).
            # Velké korpusy potřebují více paměti i více místa na disku.
            my $n_lines = get_corpus_size($corpus, $language1, 'stc');
            my $resources = $n_lines>=3000000 ? '--mem 20g --disk 100g' : '--mem 6g --disk 15g';
            dzsys::saferun("GIZASTEP=$gizastep CORPUS=$corpus SRCALIAUG=$language1~morf+stc TGTALIAUG=$language2~morf+stc eman init align --start $resources") or die;
            dzsys::saferun("GIZASTEP=$gizastep CORPUS=$corpus SRCALIAUG=$language2~morf+stc TGTALIAUG=$language1~morf+stc eman init align --start $resources") or die;
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
        my $mosesstep = find_step('mosesgiza', 'd');
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            my $alignfactor = $use_morphemes ? 'stc' : 'lemma';
            my $alignstep1 = find_step('align', "v CORPUS=$corpus v SRCALIAUG=$language1+$alignfactor v TGTALIAUG=$language2+$alignfactor");
            my $alignstep2 = find_step('align', "v CORPUS=$corpus v SRCALIAUG=$language2+$alignfactor v TGTALIAUG=$language1+$alignfactor");
            # I do not know what DECODINGSTEPS means. The value "t0-0" has been taken from eman.samples/en-cs-wmt12-small.mert.
            dzsys::saferun("BINARIES=$mosesstep ALISTEP=$alignstep1 SRCAUG=$language1+stc TGTAUG=$language2+stc DECODINGSTEPS=t0-0 eman init tm --start");
            dzsys::saferun("BINARIES=$mosesstep ALISTEP=$alignstep2 SRCAUG=$language2+stc TGTAUG=$language1+stc DECODINGSTEPS=t0-0 eman init tm --start");
        }
    }
    # Výroba překladových modelů z kombinovaných paralelních korpusů.
    if($steptype eq 'combinetm')
    {
        foreach my $language ('es', 'fr')
        {
            create_tm_for_combined_corpus("news-euro-un.$language-en", $language, 'en');
        }
    }
    # Pro každý pár vytvořit a spustit krok lm, který natrénuje jazykový model.
    # Poznámka: I když se jazykový model trénuje pouze na cílovém jazyku, model pro páry cs-en a de-en nemusí být stejný,
    # protože pro trénování využíváme cílovou stranu paralelního korpusu a ten není pro všechny páry shodný.
    if($steptype =~ m/^(lm|all)$/)
    {
        my $srilmstep = find_step('srilm', 'd');
        my $danlm = 0; # hard switch
        if(!$danlm)
        {
            # Pro news-commentary a europarl: chceme použít pouze cílovou stranu paralelního korpusu, nebo maximum textu z daného zdroje pro daný jazyk?
            # Samozřejmě předpokládám, že lepší bude to druhé. To první je zde z historických důvodů, zpočátku bylo jednodušší nezabývat se dalším korpusem.
            my $from_mono = 1;
            if($from_mono)
            {
                foreach my $corpus (@mono_training_corpora)
                {
                    my $language = get_language_code($corpus);
                    # Velké korpusy potřebují více paměti. Zatím nejmenší korpus, kterému nestačilo výchozích 6g, byl francouzský se 4+ mil. řádků.
                    my $n_lines = get_corpus_size($corpus, $language, 'stc');
                    my $mem = $n_lines>=50000000 ? ' --mem 200g' : $n_lines>=30000000 ? ' --mem 100g' : $n_lines>=4000000 ? ' --mem 30g' : '';
                    dzsys::saferun("SRILMSTEP=$srilmstep CORP=$corpus CORPAUG=$language+stc ORDER=6 eman init lm --start$mem") or die;
                }
            }
            else
            {
                foreach my $corpus (@parallel_training_corpora)
                {
                    my ($language1, $language2) = get_language_codes($corpus);
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
    # Pro každý pár vytvořit a spustit krok model, který spojí překladový model Mosese (tm), jazykový model (lm) a případné další modely.
    if($steptype =~ m/^(model|all)$/)
    {
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            my $tmstep1 = find_tm($corpus, $language1, $language2);
            my $tmstep2 = find_tm($corpus, $language2, $language1);
            my $lmstep1 = find_lm($corpus, $language2);
            my $lmstep2 = find_lm($corpus, $language1);
            # Note that the 0: before language model step identifies the factor that shall be considered in the language model.
            dzsys::saferun("TMS=$tmstep1 LMS=\"0:$lmstep1\" eman init model --start");
            dzsys::saferun("TMS=$tmstep2 LMS=\"0:$lmstep2\" eman init model --start");
        }
    }
    # Pro každý pár vytvořit a spustit krok mert, který vyladí váhy modelu (toto je Ondrův krok, který spolupracuje s Mosesem).
    if($steptype =~ m/^(model|mert|all)$/)
    {
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            my $modelstep1 = find_model($corpus, $language1, $language2);
            my $modelstep2 = find_model($corpus, $language2, $language1);
            # Note that the wmt10v6b corpus (a version of newstest2010) is not created by any step created by this danmake.pl script.
            # I manually created a step of type 'podvod' symlinked the existing augmented corpus there and registered it with corpman.
            # See the wiki for how to do it:
            # https://wiki.ufal.ms.mff.cuni.cz/user:zeman:eman#ondruv-navod-jak-prevzit-existujici-augmented-corpus
            # The mert step submits parallel translation jobs to the cluster.
            # These may be memory-intensive for some of the larger language models we use.
            # So we have to use the GRIDFLAGS parameter to make sure the jobs will get a machine with enough memory.
            # (Note that the GRIDFLAGS value will be later inherited by the translate step.)
            my $memory = $lmcorpus =~ m/gigaword/ ? '30g' : '15g';
            my $gridfl = "\"-hard -l mf=$memory -l act_mem_free=$memory -l h_vmem=$memory\"";
            dzsys::saferun("GRIDFLAGS=$gridfl MODELSTEP=$modelstep1 DEVCORP=wmt10v6b eman init mert --start");
            dzsys::saferun("GRIDFLAGS=$gridfl MODELSTEP=$modelstep2 DEVCORP=wmt10v6b eman init mert --start");
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
    # Pro každý pár vytvořit a spustit krok translate, který přeloží testovací data Mosesem.
    # If we are creating mert we will want to create translate and evaluator, too.
    # We can create them later separately but let's do it right away when we know the previous steps (they are in cache).
    if($steptype =~ m/^(model|mert|translate|all)$/)
    {
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            my $mertstep1 = find_mert($corpus, $language1, $language2);
            my $mertstep2 = find_mert($corpus, $language2, $language1);
            # Note that the wmt12v6b corpus (a version of newstest2012) is not created by any step created by this danmake.pl script.
            # I manually created a step of type 'podvod' symlinked the existing augmented corpus there and registered it with corpman.
            # See the wiki for how to do it:
            # https://wiki.ufal.ms.mff.cuni.cz/user:zeman:eman#ondruv-navod-jak-prevzit-existujici-augmented-corpus
            dzsys::saferun("MERTSTEP=$mertstep1 TESTCORP=wmt12v6b eman init translate --start");
            dzsys::saferun("MERTSTEP=$mertstep2 TESTCORP=wmt12v6b eman init translate --start");
        }
    }
    # Pro každý pár vytvořit a spustit krok evaluator, který vyhodnotí Mosesův překlad.
    # If we are creating mert we will want to create translate and evaluator, too.
    # We can create them later separately but let's do it right away when we know the previous steps (they are in cache).
    if($steptype =~ m/^(model|mert|translate|evaluator|all)$/)
    {
        foreach my $corpus (@parallel_training_corpora)
        {
            my ($language1, $language2) = get_language_codes($corpus);
            my $transtep1 = find_translate($corpus, $language1, $language2);
            my $transtep2 = find_translate($corpus, $language2, $language1);
            dzsys::saferun("TRANSSTEP=$transtep1 SCORERS=BLEU eman init evaluator --start");
            dzsys::saferun("TRANSSTEP=$transtep2 SCORERS=BLEU eman init evaluator --start");
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
}
# Make sure eman knows about new tags etc.
dzsys::saferun("eman reindex ; eman qstat");



#------------------------------------------------------------------------------
# Figures out language codes from the name of parallel corpus. Assumes that all
# names of parallel corpora end in ".xx-yy" (language codes).
#------------------------------------------------------------------------------
sub get_language_codes
{
    my $corpus = shift;
    my ($language1, $language2);
    if($corpus =~ m/\.(\w+)-(\w+)$/)
    {
        $language1 = $1;
        $language2 = $2;
        if($use_morphemes)
        {
            $language1 .= '~morf';
            $language2 .= '~morf';
        }
    }
    else
    {
        croak("Unknown languages of parallel corpus $corpus");
    }
    return ($language1, $language2);
}



#------------------------------------------------------------------------------
# Figures out language code from the name of monolingual corpus. Assumes that
# all names of monolingual corpora end in ".xx" (language code).
#------------------------------------------------------------------------------
sub get_language_code
{
    my $corpus = shift;
    my $language;
    if($corpus =~ m/\.(\w+)$/)
    {
        $language = $1;
        if($use_morphemes)
        {
            $language .= '~morf';
        }
    }
    else
    {
        croak("Unknown language of monolingual corpus $corpus");
    }
    return $language;
}



#------------------------------------------------------------------------------
# Returns number of lines of corpus. The corpus must be registered with corpman
# and we must be in the main playground folder. If the corpus is not registered
# but it is possible to derive it from existing corpora (by simple
# concatenation, for example), it will be created and we will wait for it.
#------------------------------------------------------------------------------
sub get_corpus_size
{
    my $corpus = shift;
    my $language = shift;
    my $factor = shift;
    my $step = dzsys::chompticks("corpman --wait $corpus/$language+$factor");
    $step =~ s/\s.*//;
    my @info = split(/\t/, dzsys::chompticks("cat $step/corpman.info"));
    return $info[5];
}



#------------------------------------------------------------------------------
# Najde krok s odpovídajícím překladovým modelem.
#------------------------------------------------------------------------------
sub find_tm
{
    my $parallel_corpus = shift;
    my $srclang = shift;
    my $tgtlang = shift;
    return find_step('tm', "v SRCCORP=$parallel_corpus v SRCAUG=$srclang+stc v TGTAUG=$tgtlang+stc");
}



#------------------------------------------------------------------------------
# Najde krok s odpovídajícím jazykovým modelem. Zatím se převážně držíme toho,
# že každý paralelní korpus má "svůj" jazykový model vyrobený z cílové strany
# paralelního korpusu, akorát pro news-europarl používáme o něco větší jedno-
# jazyčné verze těchto korpusů.
# Pokud je ovšem nastavena globální proměnná $lmcorpus (volbou -lm), zvolíme
# místo toho odpovídající nezávislý korpus pro daný jazyk.
#------------------------------------------------------------------------------
sub find_lm
{
    my $parallel_corpus = shift;
    my $language = shift;
    # A particular monolingual corpus can be requested via the -lm option.
    if($lmcorpus)
    {
        if($lmcorpus =~ m/^news\.\d+$/)
        {
            return find_step('lm', "v CORP=$lmcorpus.$language v CORPAUG=$language+stc");
        }
        elsif($lmcorpus =~ m/^\+news\.\d+$/)
        {
            my $mono = parallel_to_mono($parallel_corpus, $language)."$lmcorpus.$language";
            return find_step('lm', "v CORP=$mono v CORPAUG=$language+stc");
        }
        elsif($lmcorpus =~ m/^news\.all$/)
        {
            return find_step('lm', "v CORP=news.2007.$language+news.2008.$language+news.2009.$language+news.2010.$language+news.2011.$language v CORPAUG=$language+stc");
        }
        elsif($lmcorpus =~ m/^\+news\.all$/)
        {
            my $mono = parallel_to_mono($parallel_corpus, $language);
            return find_step('lm', "v CORP=$mono+news.2007.$language+news.2008.$language+news.2009.$language+news.2010.$language+news.2011.$language v CORPAUG=$language+stc");
        }
        elsif($lmcorpus eq 'gigaword')
        {
            # Gigaword je k dispozici pro angličtinu, španělštinu a francouzštinu, ale ne pro češtinu a němčinu.
            # Abychom si ušetřili kontroly na mnoha jiných místech, podstrčíme pro tyto dva jazyky místo Gigawordu něco jiného.
            if($language =~ m/^(en|es|fr)$/)
            {
                return find_step('lm', "v CORP=gigaword.$language v CORPAUG=$language+stc");
            }
            else
            {
                my $mono = parallel_to_mono($parallel_corpus, $language);
                return find_step('lm', "v CORP=$mono v CORPAUG=$language+stc");
            }
        }
        elsif($lmcorpus =~ m/^\+gigaword$/)
        {
            my $mono0 = parallel_to_mono($parallel_corpus, $language);
            my $mono1;
            if($language =~ m/^(en|es|fr)$/)
            {
                $mono1 = "+gigaword.$language";
            }
            return find_step('lm', "v CORP=$mono0$mono1 v CORPAUG=$language+stc");
        }
        else
        {
            confess("Unknown monolingual corpus $lmcorpus\n(note that the language code must not be included because it will be appended automatically)");
        }
    }
    else
    {
        my $mono = parallel_to_mono($parallel_corpus, $language);
        return find_step('lm', "v CORP=$mono v CORPAUG=$language+stc");
    }
}
sub parallel_to_mono
{
    my $parallel_corpus = shift;
    my $language = shift;
    # For some parallel corpora we have slightly larger monolingual versions for language model training.
    if($parallel_corpus =~ m/^news-europarl-v7\./)
    {
        return "news-commentary-v7.$language+europarl-v7.$language";
    }
    else
    {
        return $parallel_corpus;
    }
}



#------------------------------------------------------------------------------
# Najde krok s odpovídající kombinací překladového a jazykového modelu.
#------------------------------------------------------------------------------
sub find_model
{
    my $parallel_corpus = shift;
    my $srclang = shift;
    my $tgtlang = shift;
    my $tmstep = find_tm($parallel_corpus, $srclang, $tgtlang);
    my $lmstep = find_lm($parallel_corpus, $tgtlang);
    return find_step('model', "v TMS=$tmstep v LMS=\"0:$lmstep\"");
}



#------------------------------------------------------------------------------
# Najde krok s mertem pro danou kombinaci překladového a jazykového modelu.
#------------------------------------------------------------------------------
sub find_mert
{
    my $parallel_corpus = shift;
    my $srclang = shift;
    my $tgtlang = shift;
    my $modelstep = find_model($parallel_corpus, $srclang, $tgtlang);
    return find_step('mert', "v MODELSTEP=$modelstep");
}



#------------------------------------------------------------------------------
# Najde krok s testovacím překladem pro danou kombinaci překladového a
# jazykového modelu.
#------------------------------------------------------------------------------
sub find_translate
{
    my $parallel_corpus = shift;
    my $srclang = shift;
    my $tgtlang = shift;
    my $mertstep = find_mert($parallel_corpus, $srclang, $tgtlang);
    return find_step('translate', "v MERTSTEP=$mertstep");
}



#------------------------------------------------------------------------------
# Najde předcházející krok, na kterém závisíme. Vypíše varování, pokud daným
# kritériím odpovídá několik kroků nebo žádný krok.
#------------------------------------------------------------------------------
sub find_step
{
    my $steptype = shift;
    my $emanselect = shift;
    # Výsledky všech volání eman select v rámci jednoho běhu danmake.pl cachujeme
    # a předpokládáme, že po celou tuto dobu jsou platné. Pokud tedy generujeme
    # 20 různých mertů, které ale všechny používají tentýž jazykový model,
    # nemusíme volat emana, aby nám jazykový model hledal pořád dokola.
    my $select = "t $steptype $emanselect";
    if($stepcache{$select})
    {
        print STDERR ("Cached:    ( eman select $select ) => $stepcache{$select}\n");
        return $stepcache{$select};
    }
    my $step = dzsys::chompticks("eman select $select");
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
    $stepcache{$select} = $step;
    return $step;
}



#------------------------------------------------------------------------------
# Spojí dva korpusy do jednoho pod novým jménem. Více méně je to něco, co umí
# i corpman, až na to, že výsledný korpus nemusí mít dlouhý název obsahující
# plusy, čímž omezíme případy, kdy corpman bude vymýšlet nechtěné způsoby při
# výrobě faktorů. (Pokud corpman umí vyrobit faktor stc z faktoru lemma, a má
# vyrobit "corpA+corpB/cs+stc", pak ho může vyrobit buď z "corpA+corpB/cs+lemma",
# nebo slepením "corpA/cs+stc" a "corpB/cs+stc". Pokud máme připravená data
# jen pro jednu z obou variant, ale corpman si vezme do hlavy, že použije tu
# druhou, máme tu zbytečnou komplikaci.)
#------------------------------------------------------------------------------
sub combine_corpora
{
    my $corpus = shift; # název cílového korpusu
    my $corpus1 = shift;
    my $corpus2 = shift;
    my $language1 = shift;
    my $language2 = shift;
    # Předpokládáme, že oba korpusy obsahují pro oba jazyky faktory form, lemma a tag.
    my $path1l1 = find_corpus("$corpus1/$language1+form+lemma+tag");
    my $path1l2 = find_corpus("$corpus1/$language2+form+lemma+tag");
    my $path2l1 = find_corpus("$corpus2/$language1+form+lemma+tag");
    my $path2l2 = find_corpus("$corpus2/$language2+form+lemma+tag");
    # Předpokládáme, že soubor s korpusem je vždy zagzipovaný.
    my $commandl1 = "zcat $path1l1 $path2l1";
    my $commandl2 = "zcat $path1l2 $path2l2";
    my $n = dzsys::chompticks("$commandl1 | wc -l");
    # Nechat corpmana vyrobit krok se spojeným korpusem včetně registrace.
    dzsys::saferun("OUTCORP=$corpus OUTLANG=$language1 OUTFACTS=form+lemma+tag OUTLINECOUNT=$n TAKE_FROM_COMMAND=\"$commandl1\" eman init corpus --start") or die;
    dzsys::saferun("OUTCORP=$corpus OUTLANG=$language2 OUTFACTS=form+lemma+tag OUTLINECOUNT=$n TAKE_FROM_COMMAND=\"$commandl2\" eman init corpus --start") or die;
    # Nakonec se ujistit, že corpman ví o nově vytvořených korpusech.
    dzsys::saferun("corpman reindex") or die;
}



#------------------------------------------------------------------------------
# Spojí dva korpusy do jednoho pod novým jménem. Od funkce combine_corpora() se
# liší tím, že nepracuje s textovými daty korpusů, ale s jejich zarovnáními.
#------------------------------------------------------------------------------
sub combine_alignments
{
    my $corpus = shift; # název cílového korpusu
    my $corpus1 = shift;
    my $corpus2 = shift;
    my $language1 = shift;
    my $language2 = shift;
    # Předpokládáme, že dílčí zarovnání obsahují stejné symetrizace ve stejném pořadí.
    # Takže se sice ptáme na gdfa, ale do cílového souboru zkopírujeme všechny sloupce.
    # Také předpokládáme, že zarovnání je vždy vyrobeno nad faktorem lemma, což je zatím pravda.
    my $path1l12 = find_corpus("$corpus1/gdfa-$language1-lemma-$language2-lemma+ali");
    my $path1l21 = find_corpus("$corpus1/gdfa-$language2-lemma-$language1-lemma+ali");
    my $path2l12 = find_corpus("$corpus2/gdfa-$language1-lemma-$language2-lemma+ali");
    my $path2l21 = find_corpus("$corpus2/gdfa-$language2-lemma-$language1-lemma+ali");
    # Předpokládáme, že soubor s korpusem je vždy zagzipovaný.
    my $commandl12 = "zcat $path1l12 $path2l12";
    my $commandl21 = "zcat $path1l21 $path2l21";
    my $n = dzsys::chompticks("$commandl12 | wc -l");
    # Nechat corpmana vyrobit krok se spojeným zarovnáním včetně registrace.
    dzsys::saferun("OUTCORP=$corpus OUTLANG=gdfa-$language1-lemma-$language2-lemma OUTFACTS=ali OUTLINECOUNT=$n TAKE_FROM_COMMAND=\"$commandl12\" eman init corpus --start") or die;
    dzsys::saferun("OUTCORP=$corpus OUTLANG=gdfa-$language2-lemma-$language1-lemma OUTFACTS=ali OUTLINECOUNT=$n TAKE_FROM_COMMAND=\"$commandl21\" eman init corpus --start") or die;
    # Počkat na dokončení kroků corpus. Další úpravy můžeme provádět teprve ve chvíli, kdy budou data na místě.
    dzsys::saferun('eman wait `eman select l 2`');
    # Zjistit cesty k nově vytvořeným krokům se zarovnáními (nikoli přímo k souborům se zarovnáními).
    my $pathl12 = find_corpus("$corpus/gdfa-$language1-lemma-$language2-lemma+ali"); $pathl12 =~ s-/corpus\.txt\.gz$--;
    my $pathl21 = find_corpus("$corpus/gdfa-$language2-lemma-$language1-lemma+ali"); $pathl21 =~ s-/corpus\.txt\.gz$--;
    # Krok corpus pojmenoval soubory corpus.txt.gz. Přejmenovat je na alignment.gz.
    dzsys::saferun("mv $pathl12/corpus.txt.gz $pathl12/alignment.gz");
    dzsys::saferun("mv $pathl21/corpus.txt.gz $pathl21/alignment.gz");
    # Krok corpus si myslí, že pracoval pouze se symetrizací gdfa, a podle toho také svůj výtvor zaregistroval.
    # My ale víme, že ve skutečnosti obsahovala všech 8 známých symetrizačních heuristik. Přeregistrovat.
    open(CIL12, ">$pathl12/corpman.info") or die("Cannot write to $pathl12/corpman.info: $!");
    open(CIL21, ">$pathl21/corpman.info") or die("Cannot write to $pathl21/corpman.info: $!");
    my $i = 1;
    foreach my $sym qw(gdf revgdf gdfa revgdfa left right int union)
    {
        print CIL12 ("alignment.gz\t$i\t$corpus\t$sym-$language1-lemma-$language2-lemma\tali\t$n\n");
        print CIL21 ("alignment.gz\t$i\t$corpus\t$sym-$language2-lemma-$language1-lemma\tali\t$n\n");
        $i++;
    }
    close(CIL12);
    close(CIL21);
    # Nakonec se ujistit, že corpman ví o nově vytvořených korpusech.
    dzsys::saferun("corpman reindex") or die;
}



#------------------------------------------------------------------------------
# Returns absolute path to corpus file. Note that given corpus specification
# may refer to just one column of the file but the function just points to the
# whole file.
#------------------------------------------------------------------------------
sub find_corpus
{
    my $spec = shift;
    my $corpman = dzsys::chompticks("corpman $spec");
    my @corpman = split(/\s+/, $corpman);
    my $path = "$ENV{STATMT}/playground/$corpman[0]/$corpman[1]";
    return $path;
}



#------------------------------------------------------------------------------
# Vzhledem k tomu, že spojená zarovnání nemáme v kroku align, ale corpus,
# musíme krok tm zakládat trochu jinak a dodat některé údaje, které by se jinak
# dědily od kroku align.
#------------------------------------------------------------------------------
sub create_tm_for_combined_corpus
{
    my $corpus = shift; # corpus name
    my $language1 = shift;
    my $language2 = shift;
    my $mosesstep = find_step('mosesgiza', 'd');
    # Combined corpora typically involve large parts such as the UN corpus and tens of millions of lines.
    # We will thus require large amounts of memory and disk space.
    dzsys::saferun("BINARIES=$mosesstep SRCCORP=$corpus SRCAUG=$language1+stc TGTAUG=$language2+stc ALILABEL=$language1-lemma-$language2-lemma DECODINGSTEPS=t0-0 eman init tm --start --mem 60g --disk 200g") or die;
    dzsys::saferun("BINARIES=$mosesstep SRCCORP=$corpus SRCAUG=$language2+stc TGTAUG=$language1+stc ALILABEL=$language2-lemma-$language1-lemma DECODINGSTEPS=t0-0 eman init tm --start --mem 60g --disk 200g") or die;
}
