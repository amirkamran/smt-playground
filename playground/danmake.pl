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
    'plm' => \$plm, # in addition to the corpus specified by -lm, use also target side of parallel corpus as language model data?
    'morph|morf' => \$use_morphemes, # use language code xx~morf instead of xx
    'dryrun' => \$dryrun, # just list models and exit
);

die("Unknown step type $steptype") unless($steptype =~ m/^(special|augment|augmentbasic|combine|morfcorpus|data|align|morfalign|binarize|extract|tm|combinetm|lm|model|mert|zmert|translate|evaluator|test|all)$/);
# Zvláštní jednorázové úkoly.
if($steptype eq 'special')
{
    continue_lm_memory('running');
    #continue_tm_disk();
    exit(0);
}
# Seznam jazykových párů (momentálně pouze tyto: na jedné straně angličtina, na druhé jeden z jazyků čeština, němčina, španělština nebo francouzština)
my @pairs = qw(cs-de cs-en cs-es cs-fr de-cs de-en en-cs en-de en-es en-fr es-cs es-en fr-cs fr-en);
# Vytvořit si seznam paralelních trénovacích korpusů. Budeme z něj vycházet při zakládání jednotlivých kroků.
my @parallel_training_corpora = list_parallel_corpora();
# Vytvořit si seznam jednojazyčných trénovacích korpusů. Budeme z něj vycházet při přípravě jazykových modelů.
my @mono_training_corpora = list_monolingual_corpora();
@parallel_training_corpora = filter_corpora($firstcorpus, $lastcorpus, \@ARGV, @parallel_training_corpora);
@mono_training_corpora = filter_corpora($firstcorpus, $lastcorpus, \@ARGV, @mono_training_corpora);
# $lmcorpus určuje nezávislý jednojazyčný korpus, který se má přibalit ke krokům model, mert, translate, evaluator apod.
# Pokud uživatel zadal více takových korpusů, vytvořit stejnou sadu kroků pro každý z nich.
my @lmshortcuts = split(/,/, $lmcorpus);
my @lmcorpora;
foreach my $lms (@lmshortcuts)
{
    push(@lmcorpora, get_monolingual_corpus_names($lms));
}
# Některé kroky (např. augment) pracují jak s paralelními, tak s jednojazyčnými korpusy.
# Kroky lm pracují pouze s jednojazyčnými korpusy.
# Kroky align a tm pracují pouze s paralelními korpusy.
# Kroky model, mert, translate a evaluator pracují vždy s kombinací paralelního a jednojazyčného korpusu.
# Pro tuto poslední skupinu kroků připravit předem seznam kombinací korpusů. Např. jednojazyčné Gigawordy totiž nejsou k dispozici pro všechny jazyky.
my @models;
if($steptype eq 'lm')
{
    foreach my $mcorpus (@mono_training_corpora)
    {
        my $language = get_language_code($mcorpus);
        push(@models, {'t' => $language, 'mc' => $mcorpus});
    }
}
elsif($steptype =~ m/^(model|mert|translate|evaluator)$/)
{
    foreach my $pcorpus (@parallel_training_corpora)
    {
        my ($language1, $language2) = get_language_codes($pcorpus);
        # Jestliže nebyl požadován konkrétní jednojazyčný korpus, použít cílovou stranu paralelního korpusu.
        my $plmc1 = parallel_to_mono($pcorpus, $language1);
        my $plmc2 = parallel_to_mono($pcorpus, $language2);
        if(scalar(@lmcorpora)==0)
        {
            push(@models, {'s' => $language1, 't' => $language2, 'pc' => $pcorpus, 'mc' => $plmc2});
            push(@models, {'s' => $language2, 't' => $language1, 'pc' => $pcorpus, 'mc' => $plmc1});
        }
        # Jestliže byl požadován konkrétní jednojazyčný korpus, spojit ho s cílovou stranou paralelního korpusu.
        else
        {
            foreach my $mchash (@lmcorpora)
            {
                if($mchash->{l} eq $language1)
                {
                    # Spojení s cílovou stranou paralelního korpusu je volitelné.
                    my $mcorpus = $plm ? "$plmc1+$mchash->{c}" : $mchash->{c};
                    push(@models, {'s' => $language2, 't' => $language1, 'pc' => $pcorpus, 'mc' => $mcorpus});
                }
                if($mchash->{l} eq $language2)
                {
                    # Spojení s cílovou stranou paralelního korpusu je volitelné.
                    my $mcorpus = $plm ? "$plmc2+$mchash->{c}" : $mchash->{c};
                    push(@models, {'s' => $language1, 't' => $language2, 'pc' => $pcorpus, 'mc' => $mcorpus});
                }
            }
        }
    }
}
# Vypsat seznam kombinací korpusů.
@models = sort {"$a->{s}-$a->{t}" cmp "$b->{s}-$b->{t}"} @models;
foreach my $m (@models)
{
    print("$m->{s}-$m->{t}\t$m->{pc}\t$m->{mc}\n");
}
printf("Total %d models.\n", scalar(@models));
if($dryrun)
{
    exit(0);
}
else
{
    # Give the user the chance to spot a problem and stop the machinery.
    sleep(30);
}
my %start_step =
(
    'lm'        => \&start_lm,
    'model'     => \&start_model,
    'mert'      => \&start_mert,
    'translate' => \&start_translate,
    'evaluator' => \&start_evaluator
);
foreach my $m (@models)
{
    &{$start_step{$steptype}}($m);
}
# Make sure eman knows about new tags etc.
dzsys::saferun("eman reindex ; eman qstat");
# Stop here. The remainder of the code is outdated.
exit(0);
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
}
# Make sure eman knows about new tags etc.
dzsys::saferun("eman reindex ; eman qstat");



#==============================================================================
# SUBROUTINES
#==============================================================================



#------------------------------------------------------------------------------
# Initializes and starts a new lm step for the given corpus and language.
#------------------------------------------------------------------------------
sub start_lm
{
    my $m = shift; # reference to hash with model parameters
    my $srilmstep = find_step('srilm', 'd');
    # Velké korpusy potřebují více paměti. Zatím nejmenší korpus, kterému nestačilo výchozích 6g, byl francouzský se 4+ mil. řádků.
    my $n_lines = get_corpus_size($m->{mc}, $m->{t}, 'stc');
    my $mem = $n_lines>=50000000 ? ' --mem 200g' : $n_lines>=30000000 ? ' --mem 100g' : $n_lines>=4000000 ? ' --mem 30g' : '';
    dzsys::saferun("SRILMSTEP=$srilmstep CORP=$m->{mc} CORPAUG=$m->{t}+stc ORDER=6 eman init lm --start$mem") or die;
}



#------------------------------------------------------------------------------
# Initializes and starts a new model step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_model
{
    my $m = shift; # reference to hash with model parameters
    my $tmstep = find_tm($m->{pc}, $m->{s}, $m->{t});
    my $lmstep = find_lm($m->{mc}, $m->{t});
    # Note that the 0: before language model step identifies the factor that shall be considered in the language model.
    dzsys::saferun("TMS=$tmstep LMS=\"0:$lmstep\" eman init model --start --mem 30g");
    start_mert($m);
}



#------------------------------------------------------------------------------
# Initializes and starts a new mert step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_mert
{
    my $m = shift; # reference to hash with model parameters
    my $modelstep = find_model($m->{pc}, $m->{mc}, $m->{s}, $m->{t});
    # Note that the wmt10v6b corpus (a version of newstest2010) is not created by any step created by this danmake.pl script.
    # I manually created a step of type 'podvod' symlinked the existing augmented corpus there and registered it with corpman.
    # See the wiki for how to do it:
    # https://wiki.ufal.ms.mff.cuni.cz/user:zeman:eman#ondruv-navod-jak-prevzit-existujici-augmented-corpus
    # The mert step submits parallel translation jobs to the cluster.
    # These may be memory-intensive for some of the larger language models we use.
    # So we have to use the GRIDFLAGS parameter to make sure the jobs will get a machine with enough memory.
    # (Note that the GRIDFLAGS value will be later inherited by the translate step.)
    my $memory = $m->{mc} =~ m/gigaword/ ? '30g' : '15g';
    # Default priority is -100. Use a higher value if we need more powerful (= less abundant) machines.
    my $priority = $memory eq '30g' ? -50 : -99;
    my $gridfl = "\"-p $priority -hard -l mf=$memory -l act_mem_free=$memory -l h_vmem=$memory\"";
    dzsys::saferun("GRIDFLAGS=$gridfl MODELSTEP=$modelstep DEVCORP=wmt10v6b eman init mert --start --mem 30g");
    start_translate($m);
}



#------------------------------------------------------------------------------
# Initializes and starts a new translate step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_translate
{
    my $m = shift; # reference to hash with model parameters
    my $mertstep = find_mert($m->{pc}, $m->{mc}, $m->{s}, $m->{t});
    # Note that the wmt12v6b corpus (a version of newstest2012) is not created by any step created by this danmake.pl script.
    # I manually created a step of type 'podvod' symlinked the existing augmented corpus there and registered it with corpman.
    # See the wiki for how to do it:
    # https://wiki.ufal.ms.mff.cuni.cz/user:zeman:eman#ondruv-navod-jak-prevzit-existujici-augmented-corpus
    dzsys::saferun("MERTSTEP=$mertstep TESTCORP=wmt12v6b eman init translate --start --mem 30g");
    start_evaluator($m);
}



#------------------------------------------------------------------------------
# Initializes and starts a new evaluator step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_evaluator
{
    my $m = shift; # reference to hash with model parameters
    my $transtep = find_translate($m->{pc}, $m->{mc}, $m->{s}, $m->{t});
    dzsys::saferun("TRANSSTEP=$transtep SCORERS=BLEU eman init evaluator --start");
}



#------------------------------------------------------------------------------
# Lists available parallel corpora. A list item is either a parallel corpus or
# a combination of parallel corpora. More than one combination per language
# pair may be listed.
#------------------------------------------------------------------------------
sub list_parallel_corpora
{
    my @corpora;
    foreach my $language1 ('cs', 'de', 'es', 'fr')
    {
        my @languages2 = ('en');
        push(@languages2, 'cs') unless($language1 eq 'cs');
        foreach my $language2 (@languages2)
        {
            push(@corpora, "news-europarl-v7.$language1-$language2");
        }
    }
    push(@corpora, 'un.es-en');
    push(@corpora, 'un.fr-en');
    push(@corpora, 'news-euro-un.es-en');
    push(@corpora, 'news-euro-un.fr-en');
    return @corpora;
}



#------------------------------------------------------------------------------
# Lists available monolingual corpora. A list item is either a corpus or
# a combination of corpora. More than one combination per language may be
# listed.
#------------------------------------------------------------------------------
sub list_monolingual_corpora
{
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
    return @mono_training_corpora;
}



#------------------------------------------------------------------------------
# Expands shortcuts of monolingual corpora. For the given shortcut returns
# names of corresponding monolingual corpora in all languages in which they are
# available (e.g. the Gigaword is only available in three languages). Since
# the language is not always identifiable from corpus name (parallel corpora
# can also serve as monolingual), the result is a list of hashes of the form
# 'l' => $language, 'c' => $corpus
#------------------------------------------------------------------------------
sub get_monolingual_corpus_names
{
    my $lmcorpus = shift;
    my @results;
    my @languages = ('cs', 'de', 'en', 'es', 'fr');
    if($lmcorpus =~ m/^news\.\d+$/)
    {
        @results = map {{'l' => $_, 'c' => "$lmcorpus.$_"}} @languages;
    }
    elsif($lmcorpus =~ m/^news\.all$/)
    {
        foreach my $l (@languages)
        {
            push(@results, {'l' => $l, 'c' => join('+', map {"news.$_.$l"} (2007..2011))});
        }
    }
    elsif($lmcorpus eq 'gigaword')
    {
        # Gigaword je k dispozici pro angličtinu, španělštinu a francouzštinu, ale ne pro češtinu a němčinu.
        @languages = ('en', 'es', 'fr');
        @results = map {{'l' => $_, 'c' => "gigaword.$_"}} @languages;
    }
    return @results;
}



#------------------------------------------------------------------------------
# Returns the name of monolingual corpus that corresponds to the target side
# of the given parallel corpus. (It is not always exactly the target side of
# the parallel corpus. Occasionally we have a slightly larger set from the
# same source.)
#------------------------------------------------------------------------------
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
# Filters a list of corpora according to command-line options.
#------------------------------------------------------------------------------
sub filter_corpora
{
    my $firstcorpus = shift;
    my $lastcorpus = shift;
    my $regexes = shift; # reference to array of regular expressions
    my @corpora = @_;
    if($firstcorpus || $lastcorpus)
    {
        my $on = 0;
        my @c;
        foreach my $corpus (@corpora)
        {
            $on = 1 if($corpus eq $firstcorpus);
            push(@c, $corpus) if($on);
            $on = 0 if($corpus eq $lastcorpus);
        }
        @corpora = @c;
    }
    if(@{$regexes})
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
        (@{$regexes});
        @corpora = grep {my $corpus = $_; grep {$corpus =~ $_} (@vyber)} (@corpora);
    }
    return @corpora;
}



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
# Najde krok s odpovídajícím jazykovým modelem.
#------------------------------------------------------------------------------
sub find_lm
{
    my $mono_corpus = shift;
    my $language = shift;
    return find_step('lm', "v CORP=$mono_corpus v CORPAUG=$language+stc");
}



#------------------------------------------------------------------------------
# Najde krok s odpovídající kombinací překladového a jazykového modelu.
#------------------------------------------------------------------------------
sub find_model
{
    my $parallel_corpus = shift;
    my $mono_corpus = shift;
    my $srclang = shift;
    my $tgtlang = shift;
    my $tmstep = find_tm($parallel_corpus, $srclang, $tgtlang);
    my $lmstep = find_lm($mono_corpus, $tgtlang);
    return find_step('model', "v TMS=$tmstep v LMS=\"0:$lmstep\"");
}



#------------------------------------------------------------------------------
# Najde krok s mertem pro danou kombinaci překladového a jazykového modelu.
#------------------------------------------------------------------------------
sub find_mert
{
    my $parallel_corpus = shift;
    my $mono_corpus = shift;
    my $srclang = shift;
    my $tgtlang = shift;
    my $modelstep = find_model($parallel_corpus, $mono_corpus, $srclang, $tgtlang);
    return find_step('mert', "v MODELSTEP=$modelstep");
}



#------------------------------------------------------------------------------
# Najde krok s testovacím překladem pro danou kombinaci překladového a
# jazykového modelu.
#------------------------------------------------------------------------------
sub find_translate
{
    my $parallel_corpus = shift;
    my $mono_corpus = shift;
    my $srclang = shift;
    my $tgtlang = shift;
    my $mertstep = find_mert($parallel_corpus, $mono_corpus, $srclang, $tgtlang);
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



#==============================================================================
# MAINTENANCE SUBROUTINES
# Which steps failed, what was the reason and restarting them.
#==============================================================================



#------------------------------------------------------------------------------
# Identifies language model steps killed by the cluster because of exceeding
# memory quota. Restarts them with higher memory requirement.
#------------------------------------------------------------------------------
sub continue_lm_memory
{
    # Look for steps that have failed and are marked as failed,
    # or for those that are still marked as running (but not known to cluster)?
    my $what_to_select = shift;
    my $select_failed = $what_to_select =~ m/^failed$/i;
    my @steps;
    if($select_failed)
    {
        @steps = split(/\n/, dzsys::chompticks('eman select t lm f'));
    }
    else
    {
        @steps = split(/\n/, dzsys::chompticks('eman select t lm s running nq'));
    }
    my $n = 0;
    foreach my $step (@steps)
    {
        # Get all log file names of all previous attempts to do this step.
        my @logs = split(/\n/, dzsys::chompticks("ls $step | grep -P 'log\.o[0-9]+'"));
        if(scalar(@logs)==0)
        {
            print("No log file found!\n");
        }
        else
        {
            # Take the last log.
            # Hope that all job ids have the same number of digits so that lexicographic sorting will be equivalent to numeric.
            @logs = sort(@logs);
            my $log = $logs[-1];
            my $logpath = "$step/$log";
            my $limitsline = dzsys::chompticks("grep '== Limits:' $logpath");
            my $memory = 6;
            if($limitsline =~ m/mem_free=(\d+)g/)
            {
                $memory = $1;
            }
            unless($select_failed)
            {
                # Change the state to FAILED, which is what it really is.
                dzsys::saferun("eman fail $step");
            }
            # Do we have machines with more memory?
            if($memory>=500)
            {
                print("Even 500g of memory was not enough, giving up.\n");
                next;
            }
            $memory *= 2;
            $memory = 30 if($memory<30);
            $memory = 500 if($memory>500);
            # Re-run the step with higher memory requirement.
            # Set the highest possible priority because it may be more difficult to get a better machine.
            dzsys::saferun("eman continue $step --mem ${memory}g --priority 0");
            $n++;
        }
    }
    print("Restarted $n steps.\n");
}



#------------------------------------------------------------------------------
# Identifies failed translation model steps. Assumes that the reason of the
# failure was insufficient disk space (this is difficult to verify). Restarts
# them with higher disk requirement.
#------------------------------------------------------------------------------
sub continue_tm_disk
{
    my @steps;
    @steps = split(/\n/, dzsys::chompticks('eman select t tm f'));
    my $n = 0;
    foreach my $step (@steps)
    {
        # Get all log file names of all previous attempts to do this step.
        my @logs = split(/\n/, dzsys::chompticks("ls $step | grep -P 'log\.o[0-9]+'"));
        if(scalar(@logs)==0)
        {
            print("No log file found!\n");
        }
        else
        {
            # Take the last log.
            # Hope that all job ids have the same number of digits so that lexicographic sorting will be equivalent to numeric.
            @logs = sort(@logs);
            my $log = $logs[-1];
            my $logpath = "$step/$log";
            ###!!! The above is a remnant of attempts to get knowledge from the log.
            ###!!! However, we are not going to read the log now because it will not tell us about the previous disk requirement.
            ###!!! It would tell us the name of the machine. We could use it to locate the machine and figure out its disk space.
            # Re-run the step with higher memory requirement.
            # Set the highest possible priority because it may be more difficult to get a better machine.
            dzsys::saferun("eman continue $step --mem 30g --disk 100g --priority 0");
            $n++;
        }
    }
    print("Restarted $n steps.\n");
}
