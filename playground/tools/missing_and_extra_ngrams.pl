#!/usr/bin/perl
# Reads a reference file and an MT system output.
# Summarizes, which ngrams were not justified by any of the references
# and therefore hurted bleu
# N-grams labelled EXTRA are those not seen in any of the reference
#                MISSING are those seen in all the references but not the trans.

use strict;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

my $n = 2;
my $compare_factor = undef;
my $report_factor = undef;
my $usage = 0;
my $print_hypotheses = 0;
my $print_references = 0;
my $print_sentence_summaries = 0;
my $print_top = 30;
GetOptions(
  "n=i" => \$n,
  "help" => \$usage,
  "compare-factor=i" => \$compare_factor,
  "report-factor=i" => \$report_factor,
);

my $testfile = shift;
my @reffiles = ();
while ( my $reffile = shift ) {
  push @reffiles, $reffile;
}

die "Multiple refs not supported with --compare-factor or --report-factor"
  if 1 < scalar(@reffiles)
     && (defined $compare_factor || defined $report_factor);

if ($usage || !defined $testfile || scalar @reffiles == 0) {
  print STDERR "missing_and_extra_ngrams.pl hypothesis ref1 ref2 ...
Summarizes, which ngrams were not justified by any of the references
and therefore hurt BLEU.
Options: 
  --n=2   ... scan for how long n-grams?
  --compare-factor=undef
     ... which factor is used for checking (if undef, all factors are used)
  --report-factor=undef
     ... which factor is reported for missing or extra words
     (factors are numbered from 0)
";
  exit 1;
}

my @ref;
foreach my $reffile (@reffiles) {
  *INF = my_open($reffile);
  my $nr = 0;
  while (<INF>) {
    chomp;
    # Aachen references format:
    # my @refs = map {[split / /, $_]} split / # /;
    # push @ref, [@refs];
    push @{$ref[$nr]}, [split / /,$_];
    $nr++
  }
  close INF;
}

my @test;
*INF = my_open($testfile);
while (<INF>) {
  chomp;
  my @words = split / /;
  push @test, [@words];
}
close INF;

die "Not equal number of sentences!" if scalar @ref != scalar @test;
my $stats = compare_ngrams(\@ref, \@test, $n);

sub compare_ngrams {
  my $refs = shift;
  my $test = shift;
  my $n = shift;

  my $stats;
  for(my $sent=0; $sent < scalar @$refs; $sent++) {
    # construct hashes of seen things, compare_factor used here
    my $testngrams = ngrams($n,
      reduce_to_factor($compare_factor, $test->[$sent]));
    my $refngrams = {};
    my $allrefngrams = undef;
    foreach my $reference (@{$refs->[$sent]}) {
      my $ngrams = ngrams($n,
        reduce_to_factor($compare_factor, $reference));
      $refngrams = union($ngrams, $refngrams);
      $allrefngrams = defined $allrefngrams
                      ? intersect($ngrams, $allrefngrams)
                      : $ngrams;
    }
    if ($print_hypotheses) {
      print "$sent\t".join(" ", @{$test->[$sent]})."\n";
    }
    if ($print_references) {
      for(my $i=0; $i<scalar @{$refs->[$sent]}; $i++) {
        print "  ref$i\t".join(" ", @{$refs->[$sent]->[$i]})."\n";
      }
    }

    # Collect the statistics:
    my $tot = 0;
    my $bad = 0;
    foreach my $ngr (@{factored_ngrams($n, $test->[$sent])}) {
      $tot++;
      next if $refngrams->{$ngr->{'compare'}};
      $bad++;
      # Chance to print per-sentence problems:
      # print "  EXTRA:\t$ngr\n";
      $stats->{"extra"}->{$ngr->{'report'}}++;
    }
    if (defined $compare_factor || defined $report_factor) {
      # use only the first reference with compare_factor
      foreach my $ngr (@{factored_ngrams($n, $refs->[$sent]->[0])}) {
        next if $testngrams->{$ngr->{'compare'}};
        # Chance to print per-sentence problems:
        # print "  MISSING:\t$ngr\n";
        $stats->{"missing"}->{$ngr->{'report'}}++;
      }
    } else {
      # use all references 
      foreach my $ngr (keys %{$allrefngrams}) {
        next if $testngrams->{$ngr};
        # Chance to print per-sentence problems:
        # print "  MISSING:\t$ngr\n";
        $stats->{"missing"}->{$ngr}++;
      }
    }
    
    if ($print_sentence_summaries) {
      printf " %i bad / %i total = %.f %% $n-gram error rate\n", $bad, $tot,
        ($tot?($bad/$tot*100):0);
    }
  }
  return $stats;
}

# Report summaries:
foreach my $type (sort keys %{$stats}) {
  print "Top $print_top $type $n-grams are:\n";
  my $outnr = 0;
  foreach my $ngr (sort {$stats->{$type}->{$b} <=> $stats->{$type}->{$a}}
                   keys %{$stats->{$type}}) {
    print "$stats->{$type}->{$ngr}\t$ngr\n";
    $outnr++;
    last if $outnr >= $print_top;
  }
  print "\n";
}

sub ngrams {
  my $n = shift;
  my @words = @{shift()};
  my $out;
  while ($#words >= $n-1) {
    $out->{join(" ", @words[0..$n-1])}++;
    shift @words;
  }
  return $out;
}

sub reduce_to_factor {
  my $factor = shift;
  my $words = shift;
  return $words if ! defined $factor;
  return [ map { my @f = split /\|/, $_; $f[$factor]; } @$words ];
}

sub factored_ngrams {
  my $n = shift;
  my @words = @{shift()};
  my @words_split = map { [ split /\|/, $_ ] } @words;
  my @out;
  for(my $i=0; $i+$n-1 <= $#words; $i++) {
    my @w = @words[$i..$i+$n-1];
    my @w_split = @words_split[$i..$i+$n-1];
    # now restrict to the ngrams needed
    my $compare;
    if (defined $compare_factor) {
      $compare = join(" ", map {$_->[$compare_factor]} @w_split);
    } else {
      $compare = join(" ", @w);
    }
    my $report;
    if (defined $report_factor) {
      $report = join(" ", map {$_->[$report_factor]} @w_split);
    } else {
      $report = join(" ", @w);
    }
    push @out, {'compare'=>$compare, 'report'=>$report};
  }
  return [@out];
}

sub intersect {
  my $a = shift;
  my $b = shift;
  my $out;
  foreach my $k (%$a) {
    next if !$b->{$k};
    $out->{$k} = $a->{$k} + $b->{$k};
  }
  return $out;
}

sub union {
  my $a = shift;
  my $b = shift;
  my $out;
  foreach my $k (%$a) {
    $out->{$k} = $a->{$k};
  }
  foreach my $k (%$b) {
    $out->{$k} += $b->{$k};
  }
  return $out;
}


sub my_open {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDIN, ":utf8");
    return *STDIN;
  }

  die "Not found: $f" if ! -e $f;

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
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}
