#!/usr/bin/perl
# A simple unsupervised truecaser
# Ondrej Bojar, bojar@ufal.mff.cuni.cz
#
# Lowercase the first words of each sentence:
#   - if it is capitalized only (and not some mixed case like LaTeX), and
#   - if it is not in the list of known names (see 'model' below)
# Also 'truecase' sentences that are ALL CAPS, using the 'model' of
# typical word casings.
#
# Use --train-model=outfilename and later --model=filename to learn a list of
# "names", ie. words that do appear lowecased even in the middle of sentences.
# The words in the list then do not get lowercased even if theynot on the list of known names

use strict;
use warnings;
use Getopt::Long;

my $debug = 0;
my $fact = 0;
my $modelfile = undef;
my $outmodel_file = undef;
GetOptions(
  "factor=i" => \$fact,
  "model=s" => \$modelfile,
  "train-model=s" => \$outmodel_file,
) or exit(1);

my $col = shift;

if (!defined $col) {
  print STDERR "usage: $0 <column-index> < input
Options:
  --factor=i   ... read or write i-th factor (indexed from 0)
  --train-model=fn  ... the 'training' mode.
                    ... save all capitalized within-sentence words to fn
                    ... do not perform any lowercasing
  --model=fn  ... use the 'model' to prevent capitalized words at the
                  beginnings of sentences from lowercasing
";
  exit 1;
}

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

if (defined $outmodel_file) {
  # Train the 'model' (and exit)
  my %lex = ();
  my %occ = ();
  my $nr = 0;
  my $skipped_cap_sentences = 0;
  while (<>) {
    $nr++;
    print STDERR "." if $nr % 10000 == 0;
    chomp;
    my @cols = split /\t/;
    my $sent = $cols[$col];
    my @words = split / /, $sent;
    if (guess_sent_is_all_caps(@words)) {
      $skipped_cap_sentences++;
      next;
    }
    shift @words while @words && $words[0] !~ /[[:alpha:]]/;
      # skip all front tokens with no letter, e.g. quotation, numbers...
    shift @words; # skip first word in the sentence
    foreach my $w (@words) {
      my @facts = split /\|/, $w;
      my $f = $facts[$fact];
      shift @words if $f =~ /^[[:digit:][:punct:]]+$/;
        # do not trust words after punctuation and numbers
      next if $f !~ /[[:alpha:]]/;
        # ignore tokens with no letters
      my $shape = get_shape($f);
      $lex{lc($f)}->{$shape}++;
      $occ{lc($f)}++;
    }
  }
  print STDERR "Done $nr sents, skipped $skipped_cap_sentences capitalized sentences.\n";

  open LEX, ">$outmodel_file" or die "Can't write $outmodel_file";
  binmode LEX, ":utf8";
  foreach my $w (sort {$occ{$b}<=>$occ{$a}} keys %lex) {
    my @shapes = sort {$lex{$w}->{$b} <=> $lex{$w}->{$a}} keys %{$lex{$w}};
    my $maxshape = $shapes[0];
    print LEX lc($w)."\t".$maxshape
      ."\t".join(",", map {"$_ $lex{$w}->{$_}"} @shapes)
      ."\n";
  }
  close LEX;
  print STDERR "Model saved to: $outmodel_file\n";
  exit 0;
}

my %typshape;

# Load the 'model'
if (defined $modelfile) {
  print STDERR "Loading model: $modelfile\n";
  open LEX, $modelfile or die "Can't read $modelfile";
  binmode LEX, ":utf8";
  while (<LEX>) {
    chomp;
    my($lc, $typshape, undef) = split /\t/;
    $typshape{$lc} = $typshape;
  }
  close LEX;
}

# standard lowercasing procedure
my $nr = 0;
my $changed = 0;
while(<>) {
  $nr++;
  print STDERR "." if $nr % 10000 == 0;
  chomp;
  my @cols = split /\t/;
  my $sent = $cols[$col];
  my @words = split / /, $sent;
  my $sent_is_mostly_uppercase = guess_sent_is_all_caps(@words);
  my $first_word_with_letter = 0;
  while ($words[$first_word_with_letter] !~ /[[:alpha:]]/
      && $first_word_with_letter < $#words) {
    $first_word_with_letter++;
  }
  print STDERR "First word with letter: $first_word_with_letter: @words\n" if $debug;
  my @idxs = $sent_is_mostly_uppercase ? (0..$#words) : ($first_word_with_letter);
    # touch either all words (in an all-caps sentence) or just the first word
  
  # print STDERR "$sent_is_mostly_uppercase: $_\n";

  foreach my $idx (@idxs) {
    my $w = $words[$idx];
    my @facts = split /\|/, $w;
    my $wordform = $facts[$fact];
    print STDERR "wf $wordform  uc ".uc($wordform)
      ." is_capitalized ".is_capitalized($wordform)."\n" if $debug;
    print STDERR "typshape: ".$typshape{lc($wordform)}."\n" if $debug;
    my $op = 0;
    my $lc = lc($wordform);
    if ($sent_is_mostly_uppercase) {
      # in all-caps sents lowercase if known to lowercase or out-of-voc
      #   and is capitalized or is all caps (i.e. don't lowercase mixed case)
      # in plain sentences lowercase only if capitalized
      if (is_capitalized($wordform)
         || $wordform =~ /^[[:upper:]][[:upper:][:digit:]]*$/) {
        # capitalized and all-caps words should be lowercased or capitalized
        # based on dictionary
        # if unknown, lowercase
        if (!defined $typshape{$lc} || $typshape{$lc} eq "lc") {
          $op = "lc";
        } elsif ($typshape{$lc} eq "Cap") {
          $op = "Cap";
        }
      }
    } else {
      # in plain sentences lowercase only if capitalized or single uppercase letter
      $op = "lc" if (is_capitalized($wordform) || $wordform =~ /^[[:upper:]]$/)
                 && defined $typshape{$lc}
                 && $typshape{$lc} eq "lc";
      # and capitalize if all caps
      $op = "Cap" if $wordform =~ /^[[:upper:]][[:upper:][:digit:]]*$/
                 && defined $typshape{$lc}
                 && $typshape{$lc} eq "Cap";
    }
    if ($op) {
      print STDERR "changing  $wordform  to $op\n" if $debug;
      $wordform = lc($wordform);
      $wordform = ucfirst($wordform) if $op eq "Cap";
      $facts[$fact] = $wordform;
      $words[$idx] = join("|", @facts);
      $changed++;
    }
  }
  # print STDERR "OUT @words\n";
  $cols[$col] = join(" ", @words);
  print join("\t", @cols)."\n";
}
print STDERR "Done $nr sents, lowercased $changed.\n";

sub is_capitalized {
  my $w = shift;
  return $w =~ /^[[:upper:]][[:lower:][:digit:]]+$/;
}

sub get_shape {
  # what is the casing shape of a word
  my $w = shift;
  return "lc" if $w eq lc($w);
  return "UC" if $w eq uc($w);
  return "Cap" if is_capitalized($w);
  return "oth";
}

sub guess_sent_is_all_caps {
  my @words = map {s/\|.*//;$_} @_;
  my @relevant_words = grep {
                lc($_) !~ /^(the|a|of|an|to|in|am|is|are|s|and|about|over|for)$/
             && $_ !~ /^[[:punct:][:digit:]]+$/  } @words;
  my @cap_words = grep { /^[[:upper:]]/ } @relevant_words;
  return 0 if 0 == scalar @relevant_words;
  my $guess = (scalar @cap_words)/(scalar @relevant_words) > 0.5;
  # print STDERR "$guess <= RELEVANT: @relevant_words       CAP: @cap_words\n";
  return $guess;
}

