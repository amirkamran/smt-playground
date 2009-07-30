#!/usr/bin/perl
# generates a flmconfig based on a shape sample and factors to be used in the
# given shape

use strict;
use FindBin qw($Bin); # locate myself
my $MyDir = $Bin;

my @pismena = ( 'a' .. 'z' );

my $flmconfig = shift;
die "usage: $0 configshape-factor1+factor2"
  if ! defined $flmconfig;

my @split1 = split(/\-/, $flmconfig );

my $seedName = $split1[0];
my $factors = $split1[1];

#print "seedName: $seedName";
#print "factors: $factors";

my @facts = split(/\+/, $factors ); 

my $infname = "$MyDir/seeds/$seedName";
open(SEED, $infname) or die "Can't read $infname";

my $outfname = "$MyDir/configs/$flmconfig.flm";
open(OUTPUT, ">$outfname")
  or die "Can't write $outfname";

my $radek;
my $i;
my $pismeno;
my $f;

while ($radek = <SEED>)
{
  chomp($radek);
  $i = 0;
  foreach $f (@facts)
  {
     $pismeno = $pismena[$i];
     $radek =~ s/f_$pismeno/$f/g;
     $i++;
  }
  
  print OUTPUT $radek."\n";
}

close OUTPUT;
close SEED;
