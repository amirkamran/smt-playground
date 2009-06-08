#!/usr/bin/perl
# given a factored input produces a single-factor file
# converts Czech morphological tag to a simplified version

use strict;
no strict 'refs';
use Getopt::Long;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $tagidx = undef;
my $lemmaidx = undef;
my $formidx = undef;
my $tweak = "pos"; # which version of simplify_* to call
GetOptions(
  "tag=i" => \$tagidx,
  "lemma=i" => \$lemmaidx,
  "form=i" => \$formidx,
  "tweak=s" => \$tweak,
) or exit(1);

my $nr=0;
my $simplifier = "simplify_$tweak";
while (<>) {
  $nr++;
  print STDERR "." if $nr % 10000 == 0;
  print STDERR "($nr)" if $nr % 100000 == 0;
  chomp;
  my @out = ();
  foreach my $token (split / /) {
    my @factors = split /\|/, $token;
    push @out, &$simplifier($nr, \@factors);
  }
  print join(" ", @out)."\n";
}
print STDERR "Done.\n";

sub simplify_cng {
  my $nr = shift;
  my $factors = shift;

  my $tag = $$factors[$tagidx];
  die "Wrong tag: $tag on line $nr"
      if $tag !~ /^.{15}$/;

  return $1.$2 if $tag =~ /^([NRPA].)(...)/;
  return substr($tag, 0, 2);
}


sub simplify_nnc {
  my $nr = shift;
  my $factors = shift;

  my $tag = $$factors[$tagidx];
  die "Wrong tag: $tag on line $nr"
      if $tag !~ /^.{15}$/;

  my $neg = "x";
  my $num = "x";
  my $cas = "x";
  my @tag = split //, $tag;
  $neg = "n" if $tag[10] eq "N";
  $num = "p" if $tag[3] eq "P";
  $cas = "2" if $tag[4] eq "2";
  $cas = "1" if $tag[4] eq "1";
  return $neg.$num.$cas;
}

sub simplify_pos {
  my $nr = shift;
  my $factors = shift;

  my $tag = $$factors[$tagidx];
  die "Wrong tag: $tag on line $nr"
      if $tag !~ /^.{15}$/;

  return $1.$2 if $tag =~ /^([NRPA].)..(.)/;
  return substr($tag, 0, 2);
}


sub simplify_pos02 {
  my $nr = shift;
  my $factors = shift;

  my $tag = $$factors[$tagidx];
  die "Wrong tag: $tag on line $nr"
      if $tag !~ /^.{15}$/;
  my $lemma = $$factors[$lemmaidx];
  die "Missed lemma on line $nr." if ! defined $lemma;

  return $1.$lemma if $tag =~ /^(Z.)/;
  return $1.$2 if $tag =~ /^([NRPAC].)..(.)/;
  return substr($tag, 0, 2);
}


sub simplify_cng02 {
  my $nr = shift;
  my $factors = shift;

  my $tag = $$factors[$tagidx];
  die "Wrong tag: $tag on line $nr"
      if $tag !~ /^.{15}$/;
  my $lemma = $$factors[$lemmaidx];
  die "Missed lemma on line $nr." if ! defined $lemma;

  return $1.$lemma if $tag =~ /^(Z.)/;
  return $1.$2 if $tag =~ /^([VNRPAC].)(...)/;
  return substr($tag, 0, 2);
}


sub simplify_pos03 {
  my $nr = shift;
  my $factors = shift;

  my $tag = $$factors[$tagidx];
  die "Wrong tag: $tag on line $nr"
      if $tag !~ /^.{15}$/;
  my $lemma = $$factors[$lemmaidx];
  die "Missed lemma on line $nr." if ! defined $lemma;
  my $form = $$factors[$formidx];
  die "Missed form on line $nr." if ! defined $form;


  return $1.$lemma if $tag =~ /^([ZJT].)/;
  if ($tag =~ /^C=/) {
    $form =~ y/0123456789/5555555555/;
    return "C=$form";
  }
  return $1.$2.$lemma if $tag =~ /^([R].)..(.)/;
  return $1.$2."sesi" if $tag =~ /^(P7)..(.)/;
  return $1.$2 if $tag =~ /^([NRPAC].)..(.)/;
  if ($tag =~ /^([V].)......(.)..(.)/) {
    my $info = $1.$2.$3; # subpos, tense, aspect
    $info .= "být" if $lemma =~ /^být([-,;_]|$)/;
    return $info;
  }
  return substr($tag, 0, 2);
}


sub simplify_cng03 {
  my $nr = shift;
  my $factors = shift;

  my $tag = $$factors[$tagidx];
  die "Wrong tag: $tag on line $nr"
      if $tag !~ /^.{15}$/;
  my $lemma = $$factors[$lemmaidx];
  die "Missed lemma on line $nr." if ! defined $lemma;
  my $form = $$factors[$formidx];
  die "Missed form on line $nr." if ! defined $form;

  return $1.$lemma if $tag =~ /^([ZJT].)/;
  if ($tag =~ /^C=/) {
    $form =~ y/0123456789/5555555555/;
    return "C=$form";
  }
  return $1.$2.$lemma if $tag =~ /^([R].)(...)/;
  return $1.$2."sesi" if $tag =~ /^(P7)(...)/;
  return $1.$2 if $tag =~ /^([NRPAC].)(...)/;
  if ($tag =~ /^([V]....)...(.)..(.)/) {
    my $info = $1.$2.$3; # subpos, tense, aspect
    $info .= "být" if $lemma =~ /^být([-,;_]|$)/;
    return $info;
  }
  return substr($tag, 0, 2);
}





sub simplify_lemfive {
  my $nr = shift;
  my $factors = shift;

  my $form = $$factors[$formidx];
  die "Missed form on line $nr." if ! defined $form;

  $form =~ y/0123456789/5555555555/;
  return $form;
}


sub simplify_lemnumber {
  my $nr = shift;
  my $factors = shift;

  my $lemma = $$factors[$lemmaidx];
  die "Missed lemma on line $nr." if ! defined $lemma;
  my $form = $$factors[$formidx];
  die "Missed form on line $nr." if ! defined $form;

  return "___NUMBER___" if $form =~ /^([+-]?[0-9]+([\.,][0-9]+)?|[+-]?[\.,][0-9]+)$/;
  return $lemma;
}

