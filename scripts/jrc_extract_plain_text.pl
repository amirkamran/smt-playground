#!/usr/bin/perl

# Extracts standard plain-text parallel corpus from JRC.
#
# The working directory should contain alignment files named jrc-SRC-TGT.xml and
# folders SRC and TGT containing corpora in given languages.
#
# Also creates basic structure conforming to augmented_corpora: output files are
# automatically compressed and additional file LINE_COUNT is created, containing
# the number of lines in resulting plain-text corpus.

use strict;
use warnings;
use Getopt::Long; 
use IO::Compress::Gzip;

my ($src, $tgt, $exclude, $output_file_ids, @exclude_names, $include_hunks);
my $hunk_max_length = 100;
my $outdir = ".";
my $line_count = 0;

sub usage_string
{
    return "Usage: jrc_extract_plain_text.pl -src SRC -tgt" .
           " TGT [-outdir OUTDIR] [-exclude FILE_LIST] [-output-file-ids]\n" .
           "\n\tFILE_LIST is a file which contains names of file IDs " .
           "to be excluded from parsing (one by line).\n" .
           "\tDefault OUTDIR is `.'\n";
}

system("renice 19 $$");

if (!GetOptions(
        "src=s" => \$src,
        "tgt=s" => \$tgt,
        "outdir=s" => \$outdir,
        "exclude=s" => \$exclude,
        "include-hunks" => \$include_hunks,
        "hunk-max-length=i" => \$hunk_max_length,
        "output-file-ids" => \$output_file_ids)) {
    die(usage_string);
}

open ERR, ">$outdir/extract.err";

if (!$src || !$tgt) {
    print ERR "Missing SRC or TGT.\n";
    die(usage_string);
}

if ($exclude) {
    open (EXCLUDE, $exclude) or die("Couldn't open file " . $exclude . "\n");
    while (<EXCLUDE>) {
        chomp;
        push (@exclude_names, $_);
    }
    close EXCLUDE;
}

# returns sentence with the given number from given file handle
sub get_sentence
{
    my $file_handle = shift;
    my $number = shift;
    while (<$file_handle>) {
        my $line = $_;
        if ($line =~ m/<p n="$number">(.*)<\/p>/) {
            return $1;
        }
    }
    
    # need better error messages
    print ERR "Warning: Reached the end of file.\n";
}

open ALIGNMENTS, "jrc-$src-$tgt.xml";
my $SRC_OUT = new IO::Compress::Gzip $outdir . "/" . $src . "_txt.gz";
my $TGT_OUT = new IO::Compress::Gzip $outdir . "/" . $tgt . "_txt.gz";

my ($SRC_IN, $TGT_IN); # file handles

my $excluding = 0;
my $file_id_src;
my $file_id_tgt;

while (<ALIGNMENTS>) {
    my $line = $_;

    # start of alignment description of a file
    if ($line =~ m/^<linkGrp/) {
        # construct file paths to open
        $line =~ m/xtargets="jrcformat\/..\...\/([^;]+);jrcformat\/..\...\/([^"]+)/;
        if (!(grep {"$_-$src" eq $1} @exclude_names) &&
            !(grep {"$_-$tgt" eq $2} @exclude_names)) {
            my $file_src = "$1.xml";
            my $file_tgt = "$2.xml";
            $file_src =~ m/jrc.(....).*/;
            my $year = $1;
            $file_src =~ m/^([^-]+)/;
            $file_id_src = $1;
            $file_tgt =~ m/^([^-]+)/;
            $file_id_tgt = $1;

            if (!(open $SRC_IN, "$src/$year/$file_src")) {
                print ERR "Couldn't open file " . $file_src . "\n";
                $excluding = 1;
            }
            if (!(open $TGT_IN, "$tgt/$year/$file_tgt")) {
                print ERR "Couldn't open file " . $file_tgt . "\n";
                $excluding = 1;
            }
        } else {
            $excluding = 1;
        }
    }

    # end of alignment description
    if ($line =~ m/^<\/linkGrp/) {
        if (!$excluding) {
            close $SRC_IN;
            close $TGT_IN;
        } else {
            $excluding = 0;
        }
    }
    
    # alignment point
    if ($line =~ m/^<link type="([^"]+)" xtargets="([^;]+);([^"]+)"\/>/ && !$excluding) {
        my $type = $1;
        my $number_src = $2;
        my $number_tgt = $3;
        if ($type eq "1-1") { # extract 1-1 matches
            if ($output_file_ids) {
                print $SRC_OUT "$file_id_src\t";
                print $TGT_OUT "$file_id_tgt\t";
            }
            print $SRC_OUT get_sentence($SRC_IN, $number_src), "\n";
            print $TGT_OUT get_sentence($TGT_IN, $number_tgt), "\n";
            ++$line_count;
        } elsif ($include_hunks &&
                 $type !~ m/^0-/ &&
                 $type !~ m/-0$/) {
            my @numbers_src = split / /, $number_src;
            my @numbers_tgt = split / /, $number_tgt;
            my ($sentence_src, $sentence_tgt);
            foreach (@numbers_src) {
                $sentence_src .= get_sentence($SRC_IN, $_);
            }
            foreach (@numbers_tgt) {
                $sentence_tgt .= get_sentence($TGT_IN, $_);
            }
            my @words_src = split / /, $sentence_src;
            my @words_tgt = split / /, $sentence_tgt;
            if (scalar(@words_src) <= $hunk_max_length &&
                scalar(@words_tgt) <= $hunk_max_length) {
                print $SRC_OUT $sentence_src, "\n";
                print $TGT_OUT $sentence_tgt, "\n";
            }
        }
    }
}

close ALIGNMENTS;
close $SRC_OUT;
close $TGT_OUT;

open LINE_COUNT, ">$outdir/LINECOUNT";
print LINE_COUNT $line_count;
close LINE_COUNT;

print ERR "Done.\n";
close ERR;
