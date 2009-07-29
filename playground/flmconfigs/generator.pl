#!/bin/perl

use strict;

my @pismena = ( 'a' .. 'z'	);

my @split1 = split(/\-/, $ARGV[0] );

my $seedName = $split1[0];
my $factors = $split1[1];

#print "seedName: $seedName";
#print "factors: $factors";

my @facts = split(/\+/, $factors ); 

open(SEED, "<./seeds/$seedName");

open(OUTPUT, ">./configs/".$ARGV[0].".flm" );

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
