#!/usr/bin/perl -w

# try to lower OOV rate of a phrase-based TM by adding known unigrams
# as one-word phrases
#
# supports factored models
#
# TODO credits for the idea

use strict;
use Getopt::Long;
use File::Temp qw( tempfile tempdir );
use File::Basename;
use List::Util qw( min );

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $extract_outdir; # output directory of Moses phrase extractor
my $scripts_rootdir;
my $output_alignments = 0;
my $tempdir = "/tmp/";
my $outdir = "reduce-oov";
my $nbest = 0;
my %translations; # hash of arrays containing possible translations for target words

exit 1 if ! GetOptions(
  "e|extract-outdir=s" => \$extract_outdir,
  "s|scripts-rootdir=s" => \$scripts_rootdir,
  "a|output-alignments" => \$output_alignments,
  "n|nbest=i" => \$nbest, # output only n best translations (0 to output all)
  "t|temp-dir=s" => \$tempdir,
  "o|output-dir=s" => \$outdir);

if (! $scripts_rootdir || ! $extract_outdir) {
  die "You need to specify the Moses scripts ".
      "and phrase extractor output directories\n";
}

safesystem("mkdir -p $outdir") or die "Failed to create output directory.\n";

my $oov_pl = "$scripts_rootdir/analysis/oov.pl";
my $score = "$scripts_rootdir/training/phrase-extract/score";
my $consolidate = "$scripts_rootdir/training/phrase-extract/consolidate";

if (-e "$extract_outdir/extract") { # non-factored model
  process_phrase_table("$extract_outdir/extract", "$extract_outdir/lex", "");
} else {
  for (my @extracts = grep { ! /inv/ } glob("$extract_outdir/extract.*")) { # factored TM
    my $path = $_;
    my $filename = basename $path;
    my $factors = (split /\./, $filename)[1];
    process_phrase_table($path, "$extract_outdir/lex.$factors", "." . $factors);
  }
}

print STDERR "Done.\n";

sub process_phrase_table
{
  my ($phrase_table, $lexical_table, $factors) = @_;

  # new phrase table is printed here (not sorted yet)
  my ($output_hdl, $output_name) = tempfile(DIR => $tempdir);
  binmode $output_hdl, ":utf8";
  my ($output_inv_hdl, $output_inv_name) = tempfile(DIR => $tempdir);
  binmode $output_inv_hdl, ":utf8";
  
  my $phrase_table_hdl = try_open($phrase_table);
  
  # used as input for oov.pl
  my ($phrase_table_aux_hdl, $phrase_table_aux_name) = tempfile(DIR => $tempdir);
  binmode $phrase_table_aux_hdl, ":utf8";
  
  die "Failed to open $phrase_table\n" if ! $phrase_table_hdl;
  
  print STDERR "Reading phrase table...\n";
  
  # process the phrase table
  while (<$phrase_table_hdl>) {
    chomp;
    my @line = split / \|\|\| /;
    print $output_hdl "$line[0] ||| $line[1] ||| $line[2]\n"; # output the original phrases
    # output inverse phrase table
    print $output_inv_hdl "$line[1] ||| $line[0] ||| " . invert_alignment($line[2]) . "\n";
    print $phrase_table_aux_hdl $line[1] . "\n"; # prepare input for oov.pl
  }
  close $phrase_table_aux_hdl;
  
  my $lexical_table_hdl = try_open("$lexical_table.f2e"); # XXX e2f?
  die "Failed to open $lexical_table.f2e\n" if ! $lexical_table_hdl;
  
  # reference for oov.pl
  my ($lexical_table_aux_hdl, $lexical_table_aux_name) = tempfile(DIR => $tempdir);
  binmode $lexical_table_aux_hdl, ":utf8";
  
  print STDERR "Reading lexical table...\n";
  
  # process the lexical table
  while (<$lexical_table_hdl>) {
    chomp;
    my @line = split " ", $_;
    next if grep { $_ eq "NULL" } @line;
    print $lexical_table_aux_hdl "$line[0]\n";
    my %entry = ( translation => $line[1], prob => $line[2] );
    push @{ $translations{$line[0]} }, \%entry; 
  }
  close $lexical_table_aux_hdl;
  close $lexical_table_hdl;
  
  # run oov.pl
  print STDERR "Running oov.pl...\n";
  open(my $oov_pl_out_hdl, "cat $phrase_table_aux_name | $oov_pl --verbose $lexical_table_aux_name |");
  binmode $oov_pl_out_hdl, ":utf8";
  my $new_tokens = 0;
  
  while (<$oov_pl_out_hdl>) {
    chomp;
    my $line = $_;
    next if $line !~ m/^[0-9]/; # skip verbose info, only interested in OOV tokens
    my $token = (split "\t", $line)[1];

    # only output n best translations?
    if ($nbest) {
      my @sorted = sort { $b->{prob} <=> $a->{prob} } @{ $translations{$token} };
      @sorted = @sorted[0 .. min($#sorted, $nbest)];
      $translations{$token} = \@sorted;
    }

    for my $entry (@{ $translations{$token} }) {
      my $translation = $entry->{translation};
      print $output_hdl "$translation ||| $token ||| 0-0\n";
      print $output_inv_hdl "$token ||| $translation ||| 0-0\n";
      $new_tokens++;
    }
  }
  close $output_hdl;
  close $output_inv_hdl;
  
  print STDERR "Created $new_tokens new phrases.\n";
  
  print STDERR "Sorting the new phrase table...\n";
  safesystem("LC_ALL=C sort -T $tempdir < $output_name > $outdir/extract$factors")
    or die "Failed to sort the phrase table.\n";
  safesystem("LC_ALL=C sort -T $tempdir < $output_inv_name > $outdir/extract$factors.inv")
    or die "Failed to sort the phrase table.\n";
  
  print STDERR "Running phrase score...\n";
  my $alignment_flag = $output_alignments ? " --WordAlignment " : "";
  safesystem("$score $outdir/extract$factors $lexical_table.f2e "
    . " $outdir/phrase-table$factors.f2e $alignment_flag") 
    or die "Phrase score failed for $factors" . "f2e.\n";
  safesystem("$score $outdir/extract$factors.inv $lexical_table.e2f "
    . " $outdir/phrase-table$factors.e2f $alignment_flag --Inverse") 
    or die "Phrase score failed for $factors" . "e2f.\n";
  safesystem("LC_ALL=C sort -T $tempdir < $outdir/phrase-table$factors.e2f "
    . " > $outdir/phrase-table$factors.e2f.sorted")
    or die "Failed to sort the phrase table.\n";
  safesystem("$consolidate $outdir/phrase-table$factors.f2e $outdir/phrase-table$factors.e2f.sorted "
    . " $outdir/phrase-table$factors") 
    or die "Consolidate failed.\n";
  
  # clean up
  safesystem("rm $outdir/phrase-table$factors.*");
  unlink($output_name, $output_inv_name, $phrase_table_aux_name, $lexical_table_aux_name);
  
  # compress the final phrase table
  safesystem("(cd $outdir && gzip phrase-table$factors)")
    or die "Failed to gzip the phrase table.\n";
}

# Ondrej's smart open
sub try_open
{
  my $f = shift;
  if ($f eq "-") {
    binmode(STDIN, ":utf8");
    return *STDIN;
  }

  return undef if ! -e $f;

  my $opn;
  my $hdl;
  my $ft = `file $f`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat $f |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat $f |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or return undef;
  binmode $hdl, ":utf8";
  return $hdl;
}

sub safesystem
{
  print STDERR "Executing: @_\n";
  system(@_);
  if ($? == -1) {
      print STDERR "ERROR: Failed to execute: @_\n  $!\n";
      exit(1);
  }
  elsif ($? & 127) {
      printf STDERR "ERROR: Execution of: @_\n  died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
      exit(1);
  }
  else {
    my $exitcode = $? >> 8;
    print STDERR "Exit code: $exitcode\n" if $exitcode;
    return ! $exitcode;
  }
}

sub invert_alignment
{
  my @points = split " ", $_[0];
  my @inverted;
  for (@points) {
    my ($first, $second) = split "-";
    push @inverted, "$second-$first";
  }
  return join " ", @inverted;
}

