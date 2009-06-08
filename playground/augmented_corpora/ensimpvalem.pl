#!/usr/bin/perl
# Simplifies english valency factor

use strict;
use Getopt::Long;

my $lemf = undef;
my $formf = 0;
my $valemf = 5;
GetOptions(
  "lemma=i" => \$lemf,
  "form=i" => \$formf,
  "valem=i" => \$valemf,
) or exit 1;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $nl = 0;
while (<>) {
  $nl++;
  my $line = $_;
  chomp;
  my @toks = map { my @facts = split /\|/; [@facts] } split / /;
  my %form_to_lem = ();
  if (defined $lemf) {
    # collect all forms that will have to be mapped to lemmas
    my %need = ();
    foreach my $tok (@toks) {
      my $v = $tok->[$valemf];
      die "$nl:Missed valem: $line" if !defined $v;
      if ($v =~ /^arg[0-9]+-of-(.*)$/) {
        my $f = $1;
        $need{$f} = 1;
      }
    }
    # now collect lemmas the forms map to
    foreach my $tok (@toks) {
      my $f = $tok->[$formf];
      die "$nl:Missed form: $line" if !defined $f;
      next if ! defined $need{$f};
      my $l = $tok->[$lemf];
      die "$nl:Missed lemma: $line" if !defined $l;
      if (defined $form_to_lem{lc($f)} && $form_to_lem{lc($f)} ne lc($l)) {
        print STDERR "$nl:$line$nl:Warning! Two possible lemmas for the form $f: $l vs. $form_to_lem{$f}. Picking the older one.\n";
      } else {
        $form_to_lem{lc($f)} = $l;
      }
    }
  }

  # now prepare the new simplified valem factor
  my @out = ();
  foreach my $tok (@toks) {
    my $v = $tok->[$valemf];
    die "$nl:Missed valem: $line" if !defined $v;
    if ($v =~ /^arg([0-9]+)-of-(.*)$/) {
      my $a = $1;
      my $f = $2;
      if (defined $lemf) {
        # report argX-of-VERBLEMMA
        my $verb = $form_to_lem{lc($f)};
        die "$nl:$line$nl:Impossible, no lemma for form $f"
          if ! defined $verb;
        $v = "arg$a-of-$verb";

      } else {
        # just report argX
        $v = "arg$a";
      }
    }
    push @out, $v
  }
  print join(" ", @out)."\n";
}
