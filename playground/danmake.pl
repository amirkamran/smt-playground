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

# @ARGV obsahuje regulární výrazy pro výběr zúčastněných korpusů. Ten může být dále omezen volbami -onlys, -onlyt, -first a -last.
GetOptions
(
    'type|action=s' => \$steptype,
    'onlys=s' => \$onlys, # only models with this source language
    'onlyt=s' => \$onlyt, # only models with this target language
    'first=s' => \$firstcorpus, # useful when previous run failed but some of the jobs were submitted successfully
    'last=s' => \$lastcorpus,
    'lm=s' => \$lmcorpus, # for steps model, mert etc.: use this language model instead of the default; e.g. '-lm news.2009' will select news.2009.de for experiments to German
              # several monolingual corpora delimited by commas (e.g. -lm news.2009,news.2010) => everything will be called separately for each of them
    'plm' => \$plm, # in addition to the corpus specified by -lm, use also target side of parallel corpus as language model data?
    'morph|morf' => \$use_morphemes, # use language code xx~morf instead of xx
    'dryrun' => \$dryrun, # just list models and exit
);

die("Unknown step type $steptype") unless($steptype =~ m/^(special|restart|complete|korpus|tag|combine|morfcorpus|data|align|morfalign|binarize|extract|tm|combinetm|lm|model|mert|zmert|translate|evaluator|test|all)$/);
# Zvláštní jednorázové úkoly.
if($steptype eq 'special')
{
    if(0)
    {
        # Put your own temporary special goal here and switch it on by changing 0 -> 1 above.
    }
    else
    {
        start_inited_steps();
    }
    exit(0);
}
# Find steps that failed due to insufficient resources. Restart them with extended resource requirements.
elsif($steptype eq 'restart')
{
    continue_missing_running_steps();
    ###!!! continue_lm_memory(running) is superfluous: all such lm steps have been restarted by continue_missing_running_steps().
    ###!!! Should we rewrite the function to only handle failed steps?
    ###!!! (At least for lm steps we know that the problem was with memory. For tm steps, it could be also disk space
    ###!!! and there is no easy way to tell the two apart.)
    #continue_lm_memory('running');
    continue_lm_memory('failed');
    continue_tm_disk();
    redo_mert_memory();
}
# Find steps without expected descendants. Start the descendants.
elsif($steptype eq 'complete')
{
    start_all_missing_tms();
    start_all_missing_merts();
    start_all_missing_translates();
    start_all_missing_evaluators();
}
elsif($steptype eq 'korpus')
{
    start_korpus();
    exit(0);
}
elsif($steptype eq 'tag')
{
    start_tag();
    exit(0);
}
# Kroky lm pracují pouze s jednojazyčnými korpusy.
# Kroky align a tm pracují pouze s paralelními korpusy.
# Kroky model, mert, translate a evaluator pracují vždy s kombinací paralelního a jednojazyčného korpusu.
# Pro tuto poslední skupinu kroků připravit předem seznam kombinací korpusů. Např. jednojazyčné Gigawordy totiž nejsou k dispozici pro všechny jazyky.
my @models;
if($steptype eq 'lm')
{
    my @mcorpora = get_monolingual_corpora();
    foreach my $mcorpus (@mcorpora)
    {
        push(@models, {'t' => $mcorpus->{language}, 'mc' => $mcorpus->{corpus}});
    }
}
elsif($steptype =~ m/^(align|tm)$/)
{
    my @pcorpora = get_parallel_corpora();
    foreach my $pcorpus (@pcorpora)
    {
        # Netrénovat na malých testovacích datech, to je zbytečné.
        # (Ta, na kterých neladíme ani netestujeme, bychom mohli chtít k trénovacím datům přidat, pak by ale "wmt" nebylo na začátku.)
        next if($pcorpus->{corpus} =~ m/^wmt/);
        push(@models, {'s' => $pcorpus->{languages}[0], 't' => $pcorpus->{languages}[1], 'pc' => $pcorpus->{corpus}});
        push(@models, {'s' => $pcorpus->{languages}[1], 't' => $pcorpus->{languages}[0], 'pc' => $pcorpus->{corpus}});
    }
}
elsif($steptype =~ m/^(model|mert|translate|evaluator)$/)
{
    my @pcorpora = get_parallel_corpora();
    foreach my $pcorpus (@pcorpora)
    {
        # Netrénovat na malých testovacích datech, to je zbytečné.
        # (Ta, na kterých neladíme ani netestujeme, bychom mohli chtít k trénovacím datům přidat, pak by ale "wmt" nebylo na začátku.)
        next if($pcorpus->{corpus} =~ m/^wmt/);
        # Alternativní způsob spojování jazykových modelů (mám od Ondřeje 18.10.2012):
        # Nevytváří se nový krok lm. Místo toho se dva nebo více kroků lm vloží do jediného kroku model.
        # Mert potom každému jazykovému modelu přiřadí samostatnou váhu. Nemělo by jich tedy být příliš mnoho, aby to mert unesl.
        # Ještě jinou alternativou by byl krok mixlm, který spojí dva existující modely s váhami, váhy ale optimalizuje na perplexitu.
        ###!!! Zatím zde natvrdo vyjmenuji přídavné jazykové modely. Asi by to ale mělo být nějak podchyceno v poli korpusů.
        # 1. Pro všechna newseuro automaticky přidat i news.all cílového jazyka.
        # 2. Totéž asi i pro kombinace newseuro a něčeho dalšího paralelního (czeng, un, gigafren).
        # 3. Pro překlady do en, es, fr navíc volitelně gigaword.
        my $l1 = $pcorpus->{languages}[0];
        my $l2 = $pcorpus->{languages}[1];
        # Základní jazykový model vždy tvoří cílová strana paralelního korpusu.
        # Druhý jazykový model vždy tvoří news.all v příslušném jazyce.
        my $pmc = $pcorpus->{corpus} =~ m/^newseuro/ ? 'newseuro' : $pcorpus->{corpus};
        push(@models, {'s' => $l1, 't' => $l2, 'pc' => $pcorpus->{corpus}, 'mc' => $pmc, 'mc2' => 'newsall'});
        push(@models, {'s' => $l2, 't' => $l1, 'pc' => $pcorpus->{corpus}, 'mc' => $pmc, 'mc2' => 'newsall'});
        ###!!! Anglický Gigaword zatím vynechat! Značkování havarovalo a i když jsem to nějak poslepoval, výsledek stejně obsahuje chyby.
        ###!!! Nejlepší bude už to konečně vyhodit a přejít na značkování Featuramou.
        if($l1 =~ m/^(es|fr)$/)
        {
            push(@models, {'s' => $l2, 't' => $l1, 'pc' => $pcorpus->{corpus}, 'mc' => $pmc, 'mc2' => 'newsall', 'mc3' => 'gigaword'});
        }
        if($l2 =~ m/^(es|fr)$/)
        {
            push(@models, {'s' => $l1, 't' => $l2, 'pc' => $pcorpus->{corpus}, 'mc' => $pmc, 'mc2' => 'newsall', 'mc3' => 'gigaword'});
        }
    }
}
# Vypsat seznam kombinací korpusů.
@models = sort {"$a->{s}-$a->{t}" cmp "$b->{s}-$b->{t}"} @models;
@models = filter_models($onlys, $onlyt, $firstcorpus, $lastcorpus, \@ARGV, @models);
foreach my $m (@models)
{
    print("$m->{s}-$m->{t}\t$m->{pc}\t$m->{mc}\t$m->{mc2}\t$m->{mc3}\n");
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
    'align'     => \&start_align,
    'tm'        => \&start_tm,
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
spustit_stare_dosud_nekonvertovane_kroky();
# Make sure eman knows about new tags etc.
dzsys::saferun("eman reindex ; eman qstat");



#==============================================================================
# SUBROUTINES
#==============================================================================



#------------------------------------------------------------------------------
# Creates the list of corpora, both parallel and monolingual. This is not the
# old-fashioned list for 'augment' steps. This list uses names under which the
# corpora are / shall be registered with corpman. This function provides a
# seed from which other functions construct customized lists of parallel
# training corpora, monolingual corpora etc. Note the 'parallel' flag. Being
# available in multiple languages does not necessarily make the corpus
# parallel. On the other hand, having 'pairs' implies being parallel. Not all
# parallel corpora have 'pairs' though. Only those that have pairs in file
# names.
#------------------------------------------------------------------------------
sub get_corpora_seed
{
    my @corpora0 =
    (
      { 'corpus' => 'newseuro', 'parallel' => 1, 'pairs' => ['cs-en', 'de-en', 'es-en', 'fr-en', 'de-cs', 'es-cs', 'fr-cs'] },
      { 'corpus' => 'czeng',    'parallel' => 1, 'languages' => ['cs', 'en'] },
      { 'corpus' => 'un',       'parallel' => 1, 'pairs' => ['es-en', 'fr-en'] },
      { 'corpus' => 'gigafren', 'parallel' => 1, 'languages' => ['fr', 'en'] },
      { 'corpus' => 'newseuro', 'parallel' => 0, 'languages' => ['cs', 'de', 'en', 'es', 'fr'] },
      { 'corpus' => 'newsall',  'parallel' => 0, 'languages' => ['cs', 'de', 'en', 'es', 'fr'] },
      { 'corpus' => 'gigaword', 'parallel' => 0, 'languages' => ['en', 'es', 'fr'] },
      { 'corpus' => 'wmt2008',  'parallel' => 1, 'languages' => ['cs', 'de', 'en', 'es', 'fr'] },
      { 'corpus' => 'wmt2009',  'parallel' => 1, 'languages' => ['cs', 'de', 'en', 'es', 'fr'] },
      { 'corpus' => 'wmt2010',  'parallel' => 1, 'languages' => ['cs', 'de', 'en', 'es', 'fr'] },
      { 'corpus' => 'wmt2011',  'parallel' => 1, 'languages' => ['cs', 'de', 'en', 'es', 'fr'] },
      { 'corpus' => 'wmt2012',  'parallel' => 1, 'languages' => ['cs', 'de', 'en', 'es', 'fr'] },
    );
    return @corpora0;
}



#------------------------------------------------------------------------------
# Creates the list of all corpora, viewed monolingually. This list is suitable
# for steps that prepare and tag the corpora, i.e. both parallel and monoling.
# corpora undergo the same processing. Steps for language models will probably
# want to select only larger monolingual corpora.
#------------------------------------------------------------------------------
sub get_corpora
{
    my @corpora0 = get_corpora_seed();
    my @corpora;
    foreach my $c0 (@corpora0)
    {
        if(exists($c0->{pairs}))
        {
            foreach my $p (@{$c0->{pairs}})
            {
                if($p =~ m/^(\w+)-(\w+)$/)
                {
                    my $l1 = $1;
                    my $l2 = $2;
                    push(@corpora, {'corpus' => $c0->{corpus}, 'pair' => $p, 'language' => $l1});
                    push(@corpora, {'corpus' => $c0->{corpus}, 'pair' => $p, 'language' => $l2});
                }
                else
                {
                    die("Pair '$p' cannot be decomposed to language codes.");
                }
            }
        }
        else # No list of pairs => list of languages (monolingual corpus or test corpus of more than two languages).
        {
            foreach my $l (@{$c0->{languages}})
            {
                push(@corpora, {'corpus' => $c0->{corpus}, 'language' => $l});
            }
        }
    }
    return @corpora;
}



#------------------------------------------------------------------------------
# Creates the list of monolingual corpora suitable for language modeling.
#------------------------------------------------------------------------------
sub get_monolingual_corpora
{
    my @corpora = get_corpora_seed();
    my @mcorpora;
    foreach my $c (@corpora)
    {
        # Newsall and gigaword are monolingual-only corpora.
        # There are special monolingual versions of newseuro for all the languages. They are registered with corpman without the language code extension.
        # Besides, we can also use target languages of the large parallel corpora (czeng, un, gigafren).
        if(!$c->{parallel} || $c->{corpus} =~ m/^(czeng|gigafren)$/)
        {
            foreach my $l (@{$c->{languages}})
            {
                push(@mcorpora, {'corpus' => $c->{corpus}, 'language' => $l});
            }
        }
        elsif($c->{corpus} eq 'un')
        {
            foreach my $p (@{$c->{pairs}})
            {
                my ($l1, $l2);
                if($p =~ m/^(\S+)-(\S+)$/)
                {
                    $l1 = $1;
                    $l2 = $2;
                }
                else
                {
                    die("Cannot understand language pair '$p'.");
                }
                push(@mcorpora, {'corpus' => "$c->{corpus}.$p", 'language' => $l1});
                push(@mcorpora, {'corpus' => "$c->{corpus}.$p", 'language' => $l2});
            }
        }
    }
    return @mcorpora;
}



#------------------------------------------------------------------------------
# Creates the list of parallel corpora.
#------------------------------------------------------------------------------
sub get_parallel_corpora
{
    my @corpora = grep {$_->{parallel}} (get_corpora_seed());
    my @pcorpora;
    foreach my $c (@corpora)
    {
        # Newseuro are parallel or monolingual, depending on presence of the 'pair' attribute.
        # UN, gigafren and czeng are parallel (UN has the 'pair' attribute, gigafren and czeng have not).
        # wmt20* are multi-parallel development and test data. They do not have the 'pair' attribute.
        if(exists($c->{pairs}))
        {
            foreach my $p (@{$c->{pairs}})
            {
                my ($l1, $l2);
                if($p =~ m/^(\S+)-(\S+)$/)
                {
                    $l1 = $1;
                    $l2 = $2;
                }
                else
                {
                    die("Cannot understand language pair '$p'.");
                }
                push(@pcorpora, {'corpus' => "$c->{corpus}.$p", 'pair' => $p, 'languages' => [$l1, $l2]});
            }
        }
        else # No list of pairs => list of languages.
        {
            for(my $i = 0; $i<=$#{$c->{languages}}-1; $i++)
            {
                for(my $j = $i+1; $j<=$#{$c->{languages}}; $j++)
                {
                    my $pair = $c->{languages}[$i].'-'.$c->{languages}[$j];
                    push(@pcorpora, {'corpus' => $c->{corpus}, 'pair' => $pair, 'languages' => [$c->{languages}[$i], $c->{languages}[$j]]});
                }
            }
        }
    }
    return @pcorpora;
}



#==============================================================================
# START STEPS
#==============================================================================



#------------------------------------------------------------------------------
# Initializes and starts new korpus steps for all corpora.
#------------------------------------------------------------------------------
sub start_korpus
{
    # Remove Corpman index if any to force reindexing.
    # If there were steps for the corpora, we must have removed them first (rm -rf s.korpus.*).
    # However, the index could still refer to them.
    unlink('corpman.index') if(-e 'corpman.index');
    my @corpora = get_corpora();
    foreach my $c (@corpora)
    {
        my $corpusinit = "CORPUS=$c->{corpus} PAIR=$c->{pair} LANGUAGE=$c->{language} eman init korpus --start";
        dzsys::saferun($corpusinit) or die;
    }
}



#------------------------------------------------------------------------------
# Initializes and starts new tag steps for all corpora.
#------------------------------------------------------------------------------
sub start_tag
{
    my @corpora = get_corpora();
    print STDERR ("Tagging ", scalar(@corpora), " corpora...\n");
    foreach my $c (@corpora)
    {
        my $corpname = $c->{corpus};
        $corpname .= ".$c->{pair}" if($c->{pair} !~ m/^\s*$/);
        my $command = "CORPUS=$corpname LANGUAGE=$c->{language} eman init tag --start";
        dzsys::saferun($command) or die;
    }
}



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
# Initializes and starts a new align step for the given parallel corpus.
#------------------------------------------------------------------------------
sub start_align
{
    my $m = shift; # reference to hash with model parameters
    my $gizastep = dzsys::chompticks('eman select t mosesgiza d');
    # Odstranit corpman.index a vynutit tak přeindexování.
    # Jinak hrozí, že corpman odmítne zaregistrovat korpus, který jsme už vytvářeli dříve, i když se jeho vytvoření nepovedlo.
    dzsys::saferun('rm -f corpman.index') or die;
    # Gizawrapper vytváří nemalou pomocnou složku v /mnt/h. Měli bychom požadovat alespoň 15 GB volného místa,
    # i když už jsem viděl korpus, na který nestačilo ani 50 GB.
    my $n_lines = get_corpus_size($m->{pc}, $m->{s}, 'lemma');
    my $disk = $n_lines>=3000000 ? '100g' : '15g';
    dzsys::saferun("GIZASTEP=$gizastep CORPUS=$m->{pc} SRCALIAUG=$m->{s}+lemma TGTALIAUG=$m->{t}+lemma eman init align --start --disk $disk") or die;
    start_tm($m);
}



#------------------------------------------------------------------------------
# Initializes and starts a new tm step for the given parallel corpus.
#------------------------------------------------------------------------------
sub start_tm
{
    my $m = shift; # reference to hash with model parameters
    my $alignfactor = $use_morphemes ? 'stc' : 'lemma';
    my $alignstep = find_step('align', "v CORPUS=$m->{pc} v SRCALIAUG=$m->{s}+$alignfactor v TGTALIAUG=$m->{t}+$alignfactor");
    start_tm_for_align($m->{s}, $m->{t}, $alignstep);
}



#------------------------------------------------------------------------------
# Initializes and starts a new tm step for the given align step.
#------------------------------------------------------------------------------
sub start_tm_for_align
{
    my $src = shift;
    my $tgt = shift;
    my $alignstep = shift;
    my $mosesstep = find_step('mosesgiza', 'd');
    # I do not know what DECODINGSTEPS means. The value "t0-0" has been taken from eman.samples/en-cs-wmt12-small.mert.
    dzsys::saferun("BINARIES=$mosesstep ALISTEP=$alignstep SRCAUG=$src+stc TGTAUG=$tgt+stc DECODINGSTEPS=t0-0 eman init tm --start") or die;
}



#------------------------------------------------------------------------------
# Identifies missing tm steps (their initialization may have failed?) of
# existing align steps and initializes and starts them.
#------------------------------------------------------------------------------
sub start_all_missing_tms
{
    my @steps;
    @steps = split(/\n/, dzsys::chompticks('eman select t align u not t tm'));
    my $n = 0;
    foreach my $step (@steps)
    {
        # Figure out the languages of the align step.
        my ($src, $tgt);
        open(VARS, "eman vars $step |") or die("Cannot pipe from eman vars $step: $!");
        while(<VARS>)
        {
            if(m/SRCALIAUG=(.*?)\+/) #/ heal syntax highlighting in gedit
            {
                $src = $1;
            }
            elsif(m/TGTALIAUG=(.*?)\+/) #/ heal syntax highlighting in gedit
            {
                $tgt = $1;
            }
        }
        close(VARS);
        die("Unknown source language of step $step") unless($src);
        die("Unknown target language of step $step") unless($tgt);
        start_tm_for_align($src, $tgt, $step);
        $n++;
    }
    print("Started $n steps.\n");
}



#------------------------------------------------------------------------------
# Initializes and starts a new model step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_model
{
    my $m = shift; # reference to hash with model parameters
    my $tmstep = find_tm($m);
    my $lmsteps = get_lmsequence($m);
    dzsys::saferun("TMS=$tmstep LMS=\"$lmsteps\" eman init model --start --mem 30g");
    start_mert($m);
}



#------------------------------------------------------------------------------
# Generates packed description of language models used, as it is expected by
# the model step. Currently assumes maximum of 3 lms per experiment.
#------------------------------------------------------------------------------
sub get_lmsequence
{
    my $m = shift; # reference to hash with model parameters
    # There may be up to three language models.
    my @mcs = ($m->{mc});
    push(@mcs, $m->{mc2}) if($m->{mc2});
    push(@mcs, $m->{mc3}) if($m->{mc3});
    # Note that the 0: before language model step identifies the factor that shall be considered in the language model.
    my $lmsteps = join(':::', map {'0:'.find_lm($_, $m->{t})} (@mcs));
    return $lmsteps;
}



#------------------------------------------------------------------------------
# Initializes and starts a new mert step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_mert
{
    my $m = shift; # reference to hash with model parameters
    my $modelstep = find_model($m);
    start_mert_for_model($modelstep);
    start_translate($m);
}



#------------------------------------------------------------------------------
# Initializes and starts a new mert step for the given model step.
#------------------------------------------------------------------------------
sub start_mert_for_model
{
    my $modelstep = shift;
    # Note that the wmt10v6b corpus (a version of newstest2010) is not created by any step created by this danmake.pl script.
    # I manually created a step of type 'podvod' symlinked the existing augmented corpus there and registered it with corpman.
    # See the wiki for how to do it:
    # https://wiki.ufal.ms.mff.cuni.cz/user:zeman:eman#ondruv-navod-jak-prevzit-existujici-augmented-corpus
    # The mert step submits parallel translation jobs to the cluster.
    # These may be memory-intensive for some of the larger language models we use.
    # So we have to use the GRIDFLAGS parameter to make sure the jobs will get a machine with enough memory.
    # (Note that the GRIDFLAGS value will be later inherited by the translate step.)
    my $memory = $m->{mc} =~ m/(gigaword|un)/ || $m->{pc} =~ m/un/ ? '30g' : '15g';
    # Default priority is -100. Use a higher value if we need more powerful (= less abundant) machines.
    my $priority = $memory eq '30g' ? -50 : -99;
    my $gridfl = "\"-p $priority -hard -l mf=$memory -l act_mem_free=$memory -l h_vmem=$memory\"";
    # The above was memory for decoder jobs. Now memory for the main mert job.
    $memory = $m->{pc} =~ m/un/ ? '60g' : '30g';
    dzsys::saferun("GRIDFLAGS=$gridfl MODELSTEP=$modelstep DEVCORP=wmt10v6b eman init mert --start --mem $memory");
}



#------------------------------------------------------------------------------
# Identifies missing mert steps (their initialization may have failed?) of
# existing model steps and initializes and starts them.
#------------------------------------------------------------------------------
sub start_all_missing_merts
{
    my @steps;
    @steps = split(/\n/, dzsys::chompticks('eman select t model u not t mert'));
    my $n = 0;
    foreach my $step (@steps)
    {
        start_mert_for_model($step);
        $n++;
    }
    print("Started $n steps.\n");
}



#------------------------------------------------------------------------------
# Initializes and starts a new translate step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_translate
{
    my $m = shift; # reference to hash with model parameters
    my $mertstep = find_mert($m);
    start_translate_for_mert($mertstep);
    start_evaluator($m);
}



#------------------------------------------------------------------------------
# Initializes and starts a new translate step for the given mert step.
#------------------------------------------------------------------------------
sub start_translate_for_mert
{
    my $mertstep = shift;
    # Note that the wmt12v6b corpus (a version of newstest2012) is not created by any step created by this danmake.pl script.
    # I manually created a step of type 'podvod' symlinked the existing augmented corpus there and registered it with corpman.
    # See the wiki for how to do it:
    # https://wiki.ufal.ms.mff.cuni.cz/user:zeman:eman#ondruv-navod-jak-prevzit-existujici-augmented-corpus
    dzsys::saferun("MERTSTEP=$mertstep TESTCORP=wmt12v6b eman init translate --start --mem 30g");
}



#------------------------------------------------------------------------------
# Identifies missing translate steps (their initialization may have failed?) of
# existing mert steps and initializes and starts them.
#------------------------------------------------------------------------------
sub start_all_missing_translates
{
    my @steps;
    @steps = split(/\n/, dzsys::chompticks('eman select t mert u not t translate'));
    my $n = 0;
    foreach my $step (@steps)
    {
        start_translate_for_mert($step);
        $n++;
    }
    print("Started $n steps.\n");
}



#------------------------------------------------------------------------------
# Initializes and starts a new evaluator step for the given language pair, tm and
# lm steps (these are defined by corpus names).
#------------------------------------------------------------------------------
sub start_evaluator
{
    my $m = shift; # reference to hash with model parameters
    my $transtep = find_translate($m);
    start_evaluator_for_translate($transtep);
}



#------------------------------------------------------------------------------
# Initializes and starts a new evaluator step for the given translate step.
#------------------------------------------------------------------------------
sub start_evaluator_for_translate
{
    my $transtep = shift;
    # In spring 2012, Matouš changed something in the evaluator code and new mosesgiza template must be used.
    # However the old one must be kept too, otherwise Eman would think that all alignments must be recomputed.
    # Thus we explicitly say here which mosesgiza is to be used for the evaluator step.
    my $mosesgizastep = 's.mosesgiza.a4574321.20130123-1210';
    dzsys::saferun("TRANSSTEP=$transtep MOSESSTEP=$mosesgizastep SCORERS=BLEU eman init evaluator --start");
}



#------------------------------------------------------------------------------
# Identifies missing evaluator steps (their initialization may have failed?) of
# existing translate steps and initializes and starts them.
#------------------------------------------------------------------------------
sub start_all_missing_evaluators
{
    my @steps;
    @steps = split(/\n/, dzsys::chompticks('eman select t translate u not t evaluator'));
    my $n = 0;
    foreach my $step (@steps)
    {
        start_evaluator_for_translate($step);
        $n++;
    }
    print("Started $n steps.\n");
}



#==============================================================================
# FIND STEPS
#==============================================================================



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
# Najde krok s odpovídajícím překladovým modelem.
#------------------------------------------------------------------------------
sub find_tm
{
    my $m = shift; # model hash
    return find_step('tm', "v SRCCORP=$m->{pc} v SRCAUG=$m->{s}+stc v TGTAUG=$m->{t}+stc");
}



#------------------------------------------------------------------------------
# Najde krok s odpovídající kombinací překladového a jazykového modelu.
#------------------------------------------------------------------------------
sub find_model
{
    my $m = shift; # model hash
    my $tmstep = find_tm($m);
    my $lmsteps = get_lmsequence($m);
    return find_step('model', "v TMS=$tmstep v LMS=\"$lmsteps\"");
}



#------------------------------------------------------------------------------
# Najde krok s mertem pro danou kombinaci překladového a jazykového modelu.
#------------------------------------------------------------------------------
sub find_mert
{
    my $m = shift; # model hash
    my $modelstep = find_model($m);
    return find_step('mert', "v MODELSTEP=$modelstep");
}



#------------------------------------------------------------------------------
# Najde krok s testovacím překladem pro danou kombinaci překladového a
# jazykového modelu.
#------------------------------------------------------------------------------
sub find_translate
{
    my $m = shift; # model hash
    my $mertstep = find_mert($m);
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
# Filters a list of models/corpora according to command-line options.
#------------------------------------------------------------------------------
sub filter_models
{
    my $onlys = shift;
    my $onlyt = shift;
    my $firstcorpus = shift;
    my $lastcorpus = shift;
    my $regexes = shift; # reference to array of regular expressions
    my @models = @_;
    # The firstcorpus and lastcorpus options originally selected just corpus,
    # not language pair and direction. This is not practical when trying to
    # restart after an exception. It is possible that the same corpus is used
    # several times in different translation directions, and the occurrences
    # of the corpus in the list need not be adjacent. We thus allow that
    # optionally the corpus is described as corpus/src-tgt.
    if($firstcorpus || $lastcorpus)
    {
        my ($firstsrc, $firsttgt, $lastsrc, $lasttgt);
        if(defined($firstcorpus) && $firstcorpus =~ s/\/(.+)-(.+)$//)
        {
            $firstsrc = $1;
            $firsttgt = $2;
        }
        if(defined($lastcorpus) && $lastcorpus =~ s/\/(.+)-(.+)$//)
        {
            $lastsrc = $1;
            $lasttgt = $2;
        }
        my $on = defined($firstcorpus) ? 0 : 1;
        my @m;
        foreach my $model (@models)
        {
            $on = 1 if(defined($firstcorpus)
                       && ($model->{pc} eq $firstcorpus || $model->{mc} eq $firstcorpus)
                       && (!defined($firstsrc) || $model->{s} eq $firstsrc && $model->{t} eq $firsttgt));
            push(@m, $model) if($on);
            $on = 0 if(defined($lastcorpus)
                       && ($model->{pc} eq $lastcorpus || $model->{mc} eq $lastcorpus)
                       && (!defined($lastsrc) || $model->{s} eq $lastsrc && $model->{t} eq $lasttgt));
        }
        @models = @m;
    }
    # @{$regexes} jsou regulární výrazy pro výběr korpusů.
    if(@{$regexes})
    {
        my @vyber = @{$regexes};
        @models = grep {my $pc = $_->{pc}; my $mc = $_->{mc}; grep {$pc =~ $_ || $mc =~ $_} (@vyber)} (@models);
    }
    # onlys a onlyt jsou filtry pro výběr konkrétního zdrojového nebo cílového jazyka.
    if($onlys)
    {
        @models = grep {$_->{s} =~ $onlys} (@models);
    }
    if($onlyt)
    {
        @models = grep {$_->{t} =~ $onlyt} (@models);
    }
    return @models;
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
    my $step = dzsys::chompticks("corpman --factorindex --wait $corpus/$language+$factor");
    $step =~ s/\s.*//;
    my @info = split(/\t/, dzsys::chompticks("cat $step/corpman.info"));
    return $info[5];
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
# Finds all steps (of all types) that have been initialized only. The most
# likely reason for not starting them is that one of their dependencies had
# failed. Try to start them now.
#------------------------------------------------------------------------------
sub start_inited_steps
{
    # Look for steps that have been initialized but not started.
    my @steps;
    @steps = split(/\n/, dzsys::chompticks('eman select s inited'));
    my $n = 0;
    foreach my $step (@steps)
    {
        # Note that if the steps were started normally, danmake.pl may have asked for specific memory/disk resources.
        # We do not know what type of step it is and what the resource requirements would be, so we just leave it for failure & restart.
        dzsys::saferun("eman start $step");
        $n++;
    }
    print("Started $n steps.\n");
}



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
        unless($select_failed)
        {
            # Change the state to FAILED, which is what it really is.
            dzsys::saferun("eman fail $step");
        }
        continue_step_memory($step) and $n++;
    }
    print("Restarted $n steps.\n");
}



#------------------------------------------------------------------------------
# Identifies steps that are marked as running but not known to the cluster.
# Marks these steps as failed. Assumes that the only possible cause of such
# mysterious failure is exceeding memory quota and restarts the steps with
# higher memory requirement. (If we just marked the step as failed without
# restarting it now, we would later not know that it failed because of memory.)
#------------------------------------------------------------------------------
sub continue_missing_running_steps
{
    my @steps;
    @steps = split(/\n/, dzsys::chompticks('eman select s running nq'));
    my $n = 0;
    foreach my $step (@steps)
    {
        # Change the state to FAILED, which is what it really is.
        dzsys::saferun("eman fail $step");
        continue_step_memory($step) and $n++;
    }
    print("Restarted $n steps.\n");
}



#------------------------------------------------------------------------------
# Verifies that a step failed due to memory limit and restarts it with higher
# memory limit. (Unlike e.g. continue_lm_memory(), this function does not
# search for steps. It operates on just one step.)
#------------------------------------------------------------------------------
sub continue_step_memory
{
    my $step = shift;
    my $success = 1;
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
        # Do we have machines with more memory?
        if($memory>=500)
        {
            print("Even 500g of memory was not enough, giving up.\n");
            $success = 0;
        }
        else
        {
            $memory *= 2;
            $memory = 30 if($memory<30);
            $memory = 500 if($memory>500);
            # Besides memory, did we also require a certain amount of disk space? If so, we shall require it again.
            my $disk = '';
            if($limitsline =~ m/mnth_free=(\d+g)/)
            {
                $disk = " --disk $1";
            }
            # Re-run the step with higher memory requirement.
            # Set the highest possible priority because it may be more difficult to get a better machine.
            dzsys::saferun("eman continue $step --mem ${memory}g${disk} --priority 0");
        }
    }
    return $success;
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
            my $limitsline = dzsys::chompticks("grep '== Limits:' $logpath");
            my $disk = 50;
            if($limitsline =~ m/mnth_free=(\d+)g/)
            {
                $disk = $1;
            }
            # Do we have machines with more disk space?
            if($disk>=500)
            {
                print("Even 500g of /mnt/h space was not enough, giving up.\n");
                next;
            }
            $disk *= 2;
            $disk = 50 if($disk<50);
            $disk = 500 if($disk>500);
            # Re-run the step with higher memory requirement.
            # Set the highest possible priority because it may be more difficult to get a better machine.
            dzsys::saferun("eman continue $step --mem 30g --disk ${disk}g --priority 0");
            $n++;
        }
    }
    print("Restarted $n steps.\n");
}



#------------------------------------------------------------------------------
# Identifies mert steps killed because their decoder processes exceeded memory
# quota. Restarts them with higher memory requirement.
#------------------------------------------------------------------------------
sub redo_mert_memory
{
    # Look for failed mert steps.
    my @steps = split(/\n/, dzsys::chompticks('eman select t mert f'));
    my $n = 0;
    my @to_remove;
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
            # We cannot use dzsys::chompticks() because grep returns 1 when it does not find anything. Chompticks would die on nonzero return code.
            my $decoder_died = dzsys::qcticks("grep 'The decoder died.' $logpath");
            if($decoder_died)
            {
                my $gridflags = dzsys::chompticks("eman vars $step | grep GRIDFLAGS");
                my $memory = 6;
                if($gridflags =~ m/ mf=(\d+)g/)
                {
                    $memory = $1;
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
                # We cannot just re-run ("continue") the existing step.
                # We are about to modify one of the environment variables that define the step.
                # So we must create a new clone of the step and run that instead ("redo").
                # Set the highest possible priority because it may be more difficult to get a better machine.
                $gridflags = "-p 0 -hard -l mf=${memory}g -l act_mem_free=${memory}g -l h_vmem=${memory}g";
                # The above was memory for decoder jobs. Now memory for the main mert job.
                ###!!! Problém! Tohle je redo. Nemáme přístup k původnímu popisu korpusů, abychom vyšší požadavek řídili názvem korpusu.
                ###!!! Budeme tedy chtít víc paměti každopádně, ono to neuškodí, beztak je to něco velkého, když dekodér selhal.
                #$memory = $m->{pc} =~ m/un/ ? '60g' : '30g';
                $memory = '60g';
                # Erase all environment variables. We want Eman to see only those we define on its command line (see below).
                # Otherwise, it might think we want to reconstruct corpora with locale variables such as "LANGUAGE=en_US:en".
                my %old_environment = %ENV;
                foreach my $ev (keys(%ENV))
                {
                    # Do not erase variables needed to run eman, though!
                    ###!!! It would be better to explicitly list those variables that should be erased!
                    ###!!! We would have to read eman.vars in order to know them.
                    unless($ev =~ m/(PATH|PERL|LIB|SGE_)/)
                    {
                        delete($ENV{$ev});
                    }
                }
                dzsys::saferun("GRIDFLAGS=\"$gridflags\" eman redo $step --mem $memory --priority 0 --start");
                %ENV = %old_environment;
                push(@to_remove, $step);
                $n++;
            }
            else
            {
                print("The mert step seems to have failed because of other reasons than the death of the decoder.\n");
                print("Let's try to increase its own memory requirement.\n");
                continue_step_memory($step);
            }
        }
    }
    print("Cloned and restarted $n steps.\n");
    print("If everything went well, you may want to rm -rf the following steps:\n");
    foreach my $step (@to_remove)
    {
        print("\trm -rf $step\n");
    }
}



#------------------------------------------------------------------------------
# Archív kroků, které jsem generoval dnes už zastaralým způsobem, zatím nebyl
# čas je předělat a ani jsem je ještě k ničemu nepotřeboval.
#------------------------------------------------------------------------------
sub spustit_stare_dosud_nekonvertovane_kroky
{
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
    # Výroba překladových modelů z kombinovaných paralelních korpusů.
    if($steptype eq 'combinetm')
    {
        foreach my $language ('es', 'fr')
        {
            create_tm_for_combined_corpus("news-euro-un.$language-en", $language, 'en');
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
