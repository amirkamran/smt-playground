#!/usr/bin/perl
# Modify flm config file to use letters instead of factor names.

use strict;

my $CORPAUG = shift;
my $SourceFlm = shift;
my $TargetFlm = shift;
my $cesta = shift;

die "usage!" if ! defined $cesta;

die "Bad dir: $cesta" if ! -d $cesta;

$CORPAUG =~ s/^[^+]+\+//;

print STDERR "prepare_flm_config.pl ...\n";
print STDERR "CORPAUG = $CORPAUG\n";
print STDERR "SourceFlm = $SourceFlm\n";
print STDERR "TargetFlm = $TargetFlm\n";



my @Factors = split(/\+/, $CORPAUG);

my @NewFactors = ('a' .. 'z');

if (! -e $SourceFlm )
{
  die "file $SourceFlm does not exist!!!";
}

open(SOURCE, "<$SourceFlm") or die "Can't find $SourceFlm";
open(TARGET, ">$TargetFlm") or die "Can't write $TargetFlm";


my $j = 0;

while (<SOURCE>)
{
  chomp;

  if ($j == 1)
  {
    s/[^ ]+\.count\.gz/$cesta\/flm.count.gz/;
    s/[^ ]+\.lm\.gz/$cesta\/flm.lm.gz/;
  }

  for (my $i = 0; $i <= $#Factors; $i++)
  {
    my $f = $Factors[$i];
    my $nf = $NewFactors[$i];

    s/^$f( *:.*)$/$nf$1/;
    s/([\s,])$f([0-9\(])/$1$nf$2/g;
  }

  print TARGET $_."\n";
  $j++;
}

close SOURCE;
close TARGET;
