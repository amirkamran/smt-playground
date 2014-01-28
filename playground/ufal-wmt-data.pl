#!/usr/bin/env perl
# This script defines ÚFAL-specific paths to downloaded WMT corpora. To be called from the korpus step.
# It returns the command that sends the corpus to STDOUT.
# Copyright © 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $path = '/net/data/wmt2014';
# Arguments: corpus, language, [pair].
my $corpus = $ARGV[0];
my $language = $ARGV[1];
my $pair = $ARGV[2];
my $command;
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Main training data: Europarl and News Commentary.
# cd $WMT
# wget http://www.statmt.org/wmt13/training-parallel-europarl-v7.tgz
# wget http://www.statmt.org/wmt14/training-parallel-nc-v9.tgz
# untar it
# cd $PLAYGROUND
if($corpus eq 'news9euro')
{
    # There is no Russian Europarl. Only News Commentary will be used if Russian is involved.
    if($pair eq 'ru-en')
    {
        die("Language '$language' does not match pair '$pair'") if(!lmatchp($language, $pair));
        $command = "zcat $path/training/news-commentary-v9.$pair.$language.gz";
    }
    # Check the other languages. No Spanish this year.
    elsif($pair =~ m/^(cs|de|fr)-en$/)
    {
        die("Language '$language' does not match pair '$pair'") if(!lmatchp($language, $pair));
        $command = "zcat $path/training/europarl-v7.$pair.$language.gz $path/training/news-commentary-v9.$pair.$language.gz";
    }
    # Look for monolingual version if $pair is undefined.
    elsif(!defined($pair))
    {
        if($language eq 'ru')
        {
            $command = "zcat $path/training/news-commentary-v9.$language.gz";
        }
        elsif($language =~ m/^(cs|de|en|fr)$/)
        {
            $command = "zcat $path/training/europarl-v7.$language.gz $path/training/news-commentary-v9.$language.gz";
        }
        else
        {
            die("Unknown language '$language' for monolingual version of corpus '$corpus'");
        }
    }
    else
    {
        die("Unknown language pair '$pair' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Additional training data since 2013: Common Crawl Corpus.
# wget http://www.statmt.org/wmt13/training-parallel-commoncrawl.tgz
elsif($corpus eq 'commoncrawl')
{
    if($pair =~ m/^(cs|de|es|fr|ru)-en$/)
    {
        die("Language '$language' does not match pair '$pair'") if(!lmatchp($language, $pair));
        $command = "zcat $path/training/commoncrawl.$pair.$language.gz";
    }
    else
    {
        die("Unknown language pair '$pair' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Large Czech-English parallel corpus: Czeng.
# This corpus has been created at ÚFAL, so we do not download it from anywhere and it is not in /net/data/wmt*.
# Direct access at ÚFAL: /net/data/czeng10-public-release.
# Plain text format: Every file contains four columns. Czech sentence is in the third and English in the fourth column.
elsif($corpus eq 'czeng')
{
    my $column;
    if($language eq 'cs')
    {
        $column = 2;
    }
    elsif($language eq 'en')
    {
        $column = 3;
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
    my $perl_filter = "while(<>) { chomp; my \@c = split(\"\\t\", \$_); print(\"\$c[$column]\\n\"); }";
    open(COLUMN, '>column.pl') or die("Cannot write to column.pl: $!");
    print COLUMN ("#!/usr/bin/env perl\n");
    print COLUMN ("$perl_filter\n");
    close(COLUMN);
    chmod(0755, 'column.pl') or die("Cannot change mode of column.pl: $!");
    $command = "zcat /net/data/czeng10-public-release/data.plaintext-format/*train.gz | ./column.pl";
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# United Nations corpus: large parallel data for French, Spanish and English.
# es-en # 1,103,180,390 B
# fr-en # 1,262,447,173 B
# wget http://www.statmt.org/wmt13/training-parallel-un.tgz
elsif($corpus eq 'un')
{
    if($pair =~ m/^(es|fr)-en$/)
    {
        die("Language '$language' does not match pair '$pair'") if(!lmatchp($language, $pair));
        $command = "zcat $path/un/undoc.2000.$pair.$language.gz";
    }
    else
    {
        die("Unknown language pair '$pair' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Giga French-English parallel corpus.
# fr-en # 2,595,112,960 B
# wget http://www.statmt.org/wmt10/training-giga-fren.tar
elsif($corpus eq 'gigafren')
{
    if($language =~ m/^(fr|en)$/)
    {
        $command = "zcat $path/giga-fren.release2.$language.gz";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Yandex: parallel Russian-English corpus.
# First register on-line at https://translate.yandex.ru/corpus?lang=en.
# The owners of the corpus will send a temporary link to the data within a week from the registration, e.g.:
# wget http://clck.ru/936Hh
elsif($corpus eq 'yandex')
{
    if($language =~ m/^(ru|en)$/)
    {
        $command = "zcat $path/yandex/corpus.en_ru.1m.$language.gz";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Hindencorp: parallel English-Hindi corpus from ÚFAL.
# Username will be sent after registration, password is common.
# wget --user=XXX --password=hindencorp http://ufallab.ms.mff.cuni.cz/~bojar/hindencorp/data/hindencorp0.1.gz
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Monolingual crawled news corpus. Downloaded in separate packages for publication years. We just
# put it all together in one corpus.
# wget http://www.statmt.org/wmt13/training-monolingual-news-2007.tgz
# wget http://www.statmt.org/wmt13/training-monolingual-news-2008.tgz
# wget http://www.statmt.org/wmt13/training-monolingual-news-2009.tgz
# wget http://www.statmt.org/wmt13/training-monolingual-news-2010.tgz
# wget http://www.statmt.org/wmt13/training-monolingual-news-2011.tgz
# wget http://www.statmt.org/wmt13/training-monolingual-news-2012.tgz
# wget http://www.statmt.org/wmt14/training-monolingual-news-2013.tgz
elsif($corpus eq 'news9all')
{
    if($language =~ m/^(cs|de|en|hi|fr|ru)$/)
    {
        $command = "zcat $path/training-monolingual/news.*.$language.shuffled.gz";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Gigaword: monolingual corpus from the LDC. Mostly news text. Segments are paragraphs, not
# sentences. We have the contents of the DVD in /net/data. The original is many XML files. I have
# extracted plain text, gzipped it and prepared in $path.
elsif($corpus eq 'gigaword')
{
    if($language =~ m/^(en|fr)$/)
    {
        #$command = "$ENV{STATMT}/projects/danwmt/gigaword.pl $language";
        $command = "zcat $path/gigaword.$language.gz";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Multi-parallel test corpora in many languages. Those from the previous years are used as
# development data.
# wget http://www.statmt.org/wmt14/dev.tgz
elsif($corpus =~ m/^wmt(20(0[89]|1[0123]))$/)
{
    my $year = $1;
    my %languages =
    (
        2008 => 'cs|de|en|es|fr',
        2009 => 'cs|de|en|es|fr',
        2010 => 'cs|de|en|es|fr',
        2011 => 'cs|de|en|es|fr',
        2012 => 'cs|de|en|es|fr|ru',
        2013 => 'cs|de|en|es|fr|ru'
    );
    if($language =~ m/^($languages{$year})$/)
    {
        my $newstest = $corpus;
        if($year==2008)
        {
            $newstest =~ s/^wmt/news-test/;
        }
        else
        {
            $newstest =~ s/^wmt/newstest/;
        }
        # $SCRIPTS/desgml.pl < $WMT/test/$newstest-src.$LANGUAGE.sgm
        $command = "cat $path/dev/$newstest.$language";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
# There is a special English-Hindi development set for 2014
# because Hindi was not part of the previous evaluations and we cannot take it from there.
elsif($corpus eq 'dev2014')
{
    if($language =~ m/^(en|hi)$/)
    {
        $command = "cat $path/dev/newsdev2014.$language";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# The corpora below this line are additional corpora from the medical domain, for the medical MT
# track of WMT 2014. Some of them are parallel only, some monolingual, some are both.
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# EMEA (European Medicines Agency)
# wget http://opus.lingfil.uu.se/download.php?f=EMEA/cs-en.txt.zip
# wget http://opus.lingfil.uu.se/download.php?f=EMEA/de-en.txt.zip
# wget http://opus.lingfil.uu.se/download.php?f=EMEA/en-fr.txt.zip
elsif($corpus eq 'emea')
{
    if($pair =~ m/^(cs-en|de-en|en-fr)$/)
    {
        die("Language '$language' does not match pair '$pair'") if(!lmatchp($language, $pair));
        $command = "zcat $path/medical/EMEA.$pair.$language.gz";
    }
    else
    {
        die("Unknown language pair '$pair' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# COPPA (Corpus of Parallel Patent Applications)
# Provided on DVD, data sent on request. We already have it at ÚFAL.
# /net/data/khresmoi/wipo/original
# cd $path/medical
# data-extraction-scripts/coppa.pl /net/data/khresmoi/wipo/original
# Outputs:
# coppa-medical.fr-en.tsv -- in-domain sections of the corpus
# coppa-other.fr-en.tsv -- out-of-domain sections of the corpus
# gzip coppa-*.tsv
elsif($corpus eq 'coppa-medical')
{
    if($language eq 'en')
    {
        $command = "zcat $path/medical/$corpus.fr-en.tsv.gz | cut -f2";
    }
    elsif($language eq 'fr')
    {
        $command = "zcat $path/medical/$corpus.fr-en.tsv.gz | cut -f1";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
elsif($corpus eq 'coppa-other')
{
    if($language eq 'en')
    {
        $command = "zcat $path/medical/$corpus.fr-en.tsv.gz | cut -f2";
    }
    elsif($language eq 'fr')
    {
        $command = "zcat $path/medical/$corpus.fr-en.tsv.gz | cut -f1";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# MuchMore (Springer abstracts from medical journals)
# wget http://muchmore.dfki.de/pubs/springer_german_train_V4.2.tar.gz
# wget http://muchmore.dfki.de/pubs/springer_english_train_V4.2.tar.gz
# mkdir muchmore ; cd muchmore
# tar xzf ../springer_english_train_V4.2.tar.gz
# tar xzf ../springer_german_train_V4.2.tar.gz
# cd ..
# data-extraction-scripts/muchmore.pl muchmore | iconv -f iso8859-1 -t utf8 | gzip -c > muchmore.tsv.gz
###!!! Bacha, v tomto korpusu jsou německé přehlásky zakódovány jako "ae", "oe", "ue"!
elsif($corpus eq 'muchmore')
{
    if($language eq 'de')
    {
        $command = "zcat $path/medical/muchmore.tsv.gz | cut -f1";
    }
    elsif($language eq 'en')
    {
        $command = "zcat $path/medical/muchmore.tsv.gz | cut -f2";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# PatTR (MAREC patent collection)
# wget http://www.cl.uni-heidelberg.de/statnlpgroup/pattr/de-en.tar.gz
# wget http://www.cl.uni-heidelberg.de/statnlpgroup/pattr/en-fr.tar.gz
# mkdir pattr ; cd pattr
# tar xzf ../pattr.de-en.tar.gz ; mv pattr de-en
# tar xzf ../pattr.en-fr.tar.gz # already named en-fr
# ../data-extraction-scripts/pattr-parallel.sh de-en de en
# ../data-extraction-scripts/pattr-parallel.sh en-fr en fr
# ../data-extraction-scripts/pattr-monolingual.sh de-en de en
# ../data-extraction-scripts/pattr-monolingual.sh en-fr en fr
# gzip *.tsv
elsif($corpus =~ m/^pattr-(medical|other)$/)
{
    if($pair eq 'de-en')
    {
        if($language eq 'de')
        {
            $command = "zcat $path/medical/pattr/$corpus.*.$pair.tsv.gz | cut -f1";
        }
        elsif($language eq 'en')
        {
            $command = "zcat $path/medical/pattr/$corpus.*.$pair.tsv.gz | cut -f2";
        }
        else
        {
            die("Language '$language' does not match pair '$pair'");
        }
    }
    elsif($pair eq 'en-fr')
    {
        if($language eq 'en')
        {
            $command = "zcat $path/medical/pattr/$corpus.*.$pair.tsv.gz | cut -f1";
        }
        elsif($language eq 'fr')
        {
            $command = "zcat $path/medical/pattr/$corpus.*.$pair.tsv.gz | cut -f2";
        }
        else
        {
            die("Language '$language' does not match pair '$pair'");
        }
    }
    elsif(!defined($pair)) # monolingual part of the corpus
    {
        if($language eq 'en')
        {
            $command = "zcat $path/medical/pattr/$corpus.description.*.en.gz";
        }
        elsif($language eq 'de')
        {
            $command = "zcat $path/medical/pattr/$corpus.description.de-en.de.gz";
        }
        elsif($language eq 'fr')
        {
            $command = "zcat $path/medical/pattr/$corpus.description.en-fr.fr.gz";
        }
        else
        {
            die("Unknown language '$language' for corpus '$corpus'");
        }
    }
    else
    {
        die("Unknown language pair '$pair' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# UMLS (Unified Medical Language System) term-to-term translation dictionary
# Provided upon registration (download the 2013AB Full Release). We already have it at ÚFAL.
# /net/data/khresmoi/UMLS
# data-extraction-scripts/umls-monolingual.pl /net/data/khresmoi/UMLS/2013AB/META/MRDEF.RRF.gz
elsif($corpus eq 'umls')
{
    if(defined($pair)) # parallel part of the corpus
    {
        # They use different language codes:
        # cs ... CZE
        # de ... GER
        # en ... ENG
        # fr ... FRE
        my $src;
        my $tgt;
        my $cut;
        die("Language '$language' does not match pair '$pair'") if(!lmatchp($language, $pair));
        if($pair eq 'cs-en')
        {
            $src = 'CZE';
            $tgt = 'ENG';
            $cut = $language eq 'cs' ? 'f1' : 'f2';
        }
        elsif($pair eq 'de-en')
        {
            $src = 'GER';
            $tgt = 'ENG';
            $cut = $language eq 'de' ? 'f1' : 'f2';
        }
        elsif($pair eq 'fr-en')
        {
            $src = 'FRE';
            $tgt = 'ENG';
            $cut = $language eq 'fr' ? 'f1' : 'f2';
        }
        else
        {
            die("Unknown language pair '$pair' for corpus '$corpus'");
        }
        $command = "$path/medical/data-extraction-scripts/umls-parallel.pl -s $src -t $tgt /net/data/khresmoi/UMLS/2013AB/META/MRCONSO.RRF.*.gz | cut -$cut";
    }
    else # monolingual part of the corpus
    {
        if($language =~ m/^(cs|de|en|fr)$/)
        {
            $command = "zcat $path/medical/umls.$language.gz";
        }
        else
        {
            die("Unknown language '$language' for corpus '$corpus'");
        }
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Wikipedia Titles from health-related categories
elsif($corpus eq 'wiki-medical-titles')
{
    if($pair =~ m/^(cs|de|fr)-en$/)
    {
        die("Language '$language' does not match pair '$pair'") if(!lmatchp($language, $pair));
        my $cut = $language eq 'en' ? 'f1' : 'f2';
        $command = "zcat $path/medical/wp-medical-titles.$pair.gz | cut -$cut";
    }
    else
    {
        die("Unknown language pair '$pair' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Wikipedia Articles from health-related categories
elsif($corpus eq 'wiki-medical-articles')
{
    if($language =~ m/^(cs|de|en|fr)$/)
    {
        $command = "zcat $path/medical/wp-medical-articles.$language.gz";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# AACT (ClinicalTrials.gov)
# Monolingual English
# wget http://library.dcri.duke.edu/dtmi/ctti/2012%20AACT/2012%20Pipe%20delimited%20text%20output.zip
# mv 2012\ Pipe\ delimited\ text\ output.zip aact-pipe-delimited-text-output.zip
# mkdir aact ; cd aact
# unzip ../aact-pipe-delimited-text-output.zip
elsif($corpus eq 'aact')
{
    if($language eq 'en')
    {
        $command = "$path/medical/data-extraction-scripts/aact.pl $path/medical/aact/clinical_study.txt";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# DrugBank
# Monolingual English
# wget http://www.drugbank.ca/system/downloads/current/drugbank.xml.zip
# unzip drugbank.xml.zip ; rm drugbank.xml.zip
# data-extraction-scripts/drugbank.pl < drugbank.xml > drugbank.txt
elsif($corpus eq 'drugbank')
{
    if($language eq 'en')
    {
        $command = "$path/medical/data-extraction-scripts/drugbank.pl < $path/medical/drugbank.xml";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# GENIA (Biomedical Literature)
# Monolingual English
# wget http://www.nactem.ac.uk/GENIA/current/GENIA-corpus/Part-of-speech/GENIAcorpus3.02p.tgz
# mkdir genia ; cd genia
# unzip.pl ../GENIAcorpus3.02p.tgz
elsif($corpus eq 'genia')
{
    if($language eq 'en')
    {
        $command = "$path/medical/data-extraction-scripts/genia.sh < $path/medical/genia/GENIAcorpus3.02.merged.xml";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# GREC (Gene Regulation Event Corpus)
# Monolingual English
# wget http://www.nactem.ac.uk/download.php?target=GREC/GREC_Standoff.zip
# mv download.php\?target\=GREC%2FGREC_Standoff.zip grec.zip
# mkdir grec ; cd grec
# unzip ../grec.zip
elsif($corpus eq 'grec')
{
    if($language eq 'en')
    {
        $command = "cat $path/medical/grec/GREC_Standoff/{Ecoli,Human}/*.txt";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# FMA (Foundational Model of Anatomy Ontology)
# Monolingual English
# wget http://sig.biostr.washington.edu/share/downloads/fma/FMA_Release/alt/v3.2.1/owl_file/fma_3.2.1_owl_file.zip
# mkdir fma ; cd fma
# unzip ../fma_3.2.1_owl_file.zip
elsif($corpus eq 'fma')
{
    if($language eq 'en')
    {
        $command = "cat $path/medical/fma/fma3.2.owl | $path/medical/data-extraction-scripts/fma.sh";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# PIL (Patient Information Leaflet Corpus)
# Monolingual English
# wget http://mcs.open.ac.uk/nlg/old_projects/pills/corpus/PIL-corpus-2.0.tar.gz
# unzip.pl PIL-corpus-2.0.tar.gz
elsif($corpus eq 'pil')
{
    if($language eq 'en')
    {
        $command = "$path/medical/data-extraction-scripts/pil.sh $path/medical/PIL-corpus-2.0/PIL/html";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
# Medical task development data
# wget http://www.statmt.org/wmt14/medical-task/khresmoi-query-test-set.tgz
# wget http://www.statmt.org/wmt14/medical-task/khresmoi-summary-test-set.tgz
elsif($corpus eq 'khresmoi-(query|summary)-dev')
{
    my $set = $1;
    if($language =~ m/^(en|cs|de|fr)$/)
    {
        $command = "cat $path/medical/khresmoi-$set-test-set/khresmoi-$set-dev.$language";
    }
    else
    {
        die("Unknown language '$language' for corpus '$corpus'");
    }
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
else
{
    die("Unknown corpus '$corpus'");
}
# Print the command to the standard output so that the caller can use it.
print("$command\n");



#------------------------------------------------------------------------------
# Checks whether language is compatible with language pair.
#------------------------------------------------------------------------------
sub lmatchp
{
    my $language = shift;
    my $pair = shift;
    my @languages = split(/-/, $pair);
    return 0 if(scalar(@languages) != 2);
    return $language eq $languages[0] || $language eq $languages[1];
}
