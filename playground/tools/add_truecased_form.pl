#!/usr/bin/env perl
# Supervised truecasing (based on the lemma).
# Expects: form|lemma
# Peeks at the first char of the lemma and lowercases the form if necessary.
# The form is either appended as a third factor or replaced in place.
use utf8;
use strict;
use Getopt::Long;

my $replace_form = 0; # replace form in place
my $no_info = 0; # don't collect any statistics
GetOptions(
  "replace-form" => \$replace_form,
  "no-info" => \$no_info,
) or exit 1;

usage() if 0 == scalar @ARGV;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

sub usage {
  print STDERR
"usage: add_truecased_form.pl column:lemma_factor:form_factor:[1|0] \\
           column:lem_f...
Adds a new factor with the form truecased according to the case of lemma.
If the fourth item is 1, the strip lemma suffix (for Czech morphology).
  --replace-form   ... do not add the factor, just replace the form
  --no-info  ... don't collect statistics (which might not fit into memory)
\n";
  print STDERR
  exit 1;
}

sub isnum {
  my $s = shift;
  return $s =~ /^[[:digit:]]+$/;
}

sub guess_case {
  my $w = shift;
  return "num" if isnum($w);
  return "punct" if $w =~ /^[[:punct:]]$/;
  return "lc" if $w =~ /^[[:lower:][:digit:]]+$/;
  return "UC" if $w =~ /^[[:upper:][:digit:]]+$/;
  return "Cap" if $w =~ /^[[:upper:]][[:lower:][:digit:]]+$/;
  return "mIx" if $w =~ /^[[:lower:]].*[[:upper:]].*[[:lower:]]/;
  return "MiX" if $w =~ /^[[:upper:]].*[[:lower:]].*[[:upper:]]/;
  return "oth";
}

sub perform_case {
  my $w = shift;
  my $tgt = shift;

  my $lc = lc($w);
  return lc($tgt) if $w eq $lc;
  my $ucfirst = ucfirst($lc);
  return ucfirst(lc($tgt)) if $w eq $ucfirst;
  my $uc = uc($w);
  return uc($tgt) if $w eq $uc;
  return $tgt; # mixed case, keep intact
}

my @updates = map {
      my ($col, $lemf, $formf, $striplem) = split /:/, $_;
      usage() if !isnum($col) || !isnum($lemf) || !isnum($formf);
      [ $col, $lemf, $formf, $striplem ];
    } @ARGV;
@ARGV = ();

my $stats;
my $totals;
my $samples;
my $nl = 0;
while (<>) {
  $nl++;
  print STDERR "." if $nl % 10000 == 0;
  chomp;
  my @line = split /\t/;
  for(my$u=0; $u<@updates; $u++) {
    my ($col, $lemf, $formf, $striplem) = @{$updates[$u]};
    my @wrds = split / /, $line[$col];
    my @outwrds = ();
    for(my $wi=0; $wi<@wrds; $wi++) {
      my $w = $wrds[$wi];
      my @facts = split /\|/,$w;
      my $is_first_in_sent = ($wi == 0);
      my $lemma = $facts[$lemf];
      if ($striplem) {
        ###!!! DZ: Every now and then I get the 'Malformed UTF-8 character (fatal)' error on the following regexes and I don't know why.
        if (!utf8::is_utf8($lemma)) { print STDERR ("Bad lemma\n"); print STDERR ("$lemma\n"); }
        else {
        #print STDERR ("Lemma $lemma seems OK.\n");
        $lemma =~ s/(.)[`_].*$/\1/;
        $lemma =~ s/(.)-[0-9]+$/\1/;
        }
      }
      my $truecased = perform_case($lemma, $facts[$formf]);
      my $shape = guess_case($lemma)
        ."\t".guess_case($facts[$formf])
        ."\t$is_first_in_sent"
        ."\t=> ".guess_case($truecased);
      if (!$no_info) {
        $stats->{$shape}->[$u]++;
        $samples->{$shape}->[$u]->{$lemma}++;
        $totals->{$shape}++;
      }
      my $ow;
      if ($replace_form) {
        $facts[$formf] = $truecased;
        $ow = join("|", @facts);
      } else {
        $ow = $w."|".$truecased;
      }
      push @outwrds, $ow;
    }
    $line[$col] = join(" ", @outwrds);
  }
  print join("\t", @line)."\n";
}
print STDERR "Done.\n";

if (!$no_info) {
  print STDERR "lemma\tform\tfirst_in_sent\tcreated\t";
  print STDERR join("\t", map { "col: ".$_->[0]."\tsamples" } @updates)."\n";
  foreach my $shape (sort {$totals->{$a}<=>$totals->{$b}} keys %$stats) {
    print STDERR $shape;
    for(my$u=0; $u<@updates; $u++) {
      my $cnt = $stats->{$shape}->[$u];
      $cnt = 0 if ! defined $cnt;
      print STDERR "\t".$cnt;
      my $samples_produced = 0;
      print STDERR "\t";
      foreach my $sample (
        sort {$samples->{$shape}->[$u]->{$b} <=> $samples->{$shape}->[$u]->{$a}}
        keys %{$samples->{$shape}->[$u]}) {
        print STDERR $sample." ";
        $samples_produced++;
        last if $samples_produced > 2;
      }
    }
    print STDERR "\n";
  }
}

