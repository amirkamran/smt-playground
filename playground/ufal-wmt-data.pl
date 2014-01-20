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
else
{
    die("Unknown corpus '$corpus'");
}
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
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
