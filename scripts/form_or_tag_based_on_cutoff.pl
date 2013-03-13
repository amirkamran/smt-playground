#!/usr/bin/perl
# reads Czech form/stc, lemma, tag
# produces a single factor, which is either:
# - the original form/stc, if the word is among top N listed in the given
#   freqlist
# - One of the following, based on your choice:
#   - the full tag
#   - the last S chars (suffix)
#
#  All digits are changed to 5 in any case.

use strict;
use utf8;
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $emit = "tag";
my $take_freq_words = 100;
GetOptions(
  "emit=s" => \$emit, # what to emit
  "take=i" => \$take_freq_words, # how many top-freq words to take
    # will take this many plus all that have the same freq
) or exit 1;

my $freqlistf = shift;

if (!defined $freqlistf) {
  print STDERR "usage: $0 freqlist < corpus
";
  exit 1;
}

my $emitf = undef; # the function that creates the emited token

if ($emit eq "tag") {
  $emitf = sub {
    my ($f, $l, $t) = @_;
    return $t;
  }
} elsif ($emit =~ /^suf([0-9]+)$/) {
  my $suflen = $1;
  $emitf = sub {
    my ($f, $l, $t) = @_;
    return "...".$1 if $f =~ /(.{$suflen})$/;
    return $f;
  }
} elsif ($emit =~ /^possuf([0-9]+)$/) {
  my $suflen = $1;
  $emitf = sub {
    my ($f, $l, $t) = @_;
    my $posprefix = substr($t, 0, 1)."+";
    return $posprefix."...".$1 if $f =~ /.(.{$suflen})$/;
    return $posprefix.$f;
  }
} else {
  die "Undefined request: '$emit'";
}

my %freqenough = ();

my $fh = my_open($freqlistf);
my $lastfreq = undef;
my $gotwords = 0;
my $nr = 0;
while (<$fh>) {
  $nr++;
  chomp;
  s/^\s+//;
  s/\s+$//;
  my ($freq, $word) = split /\t/;
  die "$freqlistf:$nr:Word '$word' not lowercase, freqlist invalid"
    if $word ne lc($word);
  die "$freqlistf:$nr:Frequency not descending, freqlist invalid"
    if defined $lastfreq && $freq > $lastfreq;
  if ($gotwords < $take_freq_words) {
    $gotwords++;
  } else { # gotwords == take_freq_words
    $gotwords++ if $lastfreq != $freq;
      # keep getting more words of the same freq
  }
  if ($gotwords <= $take_freq_words+1) {
    # print STDERR "gotw $gotwords, lastf $lastfreq, f $freq: $word\n";
    $freqenough{$word} = 1 if $lastfreq;
  }
  $lastfreq = $freq;
  # keep reading to validate the whole freqlist
}
close $fh;

print STDERR "Asked to use top $take_freq_words words from: $freqlistf.\n";
print STDERR "Will actually keep ",
  scalar(keys %freqenough), " of the available $nr ones.\n";

my $nr = 0;
while (<>) {
  $nr++;
  chomp;
  my @toks = split / /;
  my @out = ();
  foreach my $tok (@toks) {
    my ($form, $lemma, $tag) = split /\|/, $tok;
    # print STDERR "$tok:  $form   $lemma    $tag\n";
    $form =~ y/1234567890/5555555555/;
    my $lcform = lc($form); # we will use lcform when checking the freqlist
    my $out;
    if ($freqenough{$lcform}) {
      $out = $form;
    } else {
      $out = $emitf->($form, $lemma, $tag);
      # print STDERR "----> $out\n";
    }
    push @out, $out;
  }
  my $out = join(" ", @out);
  print $out."\n";
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
  my $ft = `file '$f'`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat '$f' |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat '$f' |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}
