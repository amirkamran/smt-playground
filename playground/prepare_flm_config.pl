#!/usr/bin/perl

$CORPAUG = shift;
$SourceFlm = shift;
$TargetFlm = shift;

$CORPAUG =~ s/^[^+]+\+(.*)$/$1/;

print STDERR "prepare_flm_config.pl ...\n";
print STDERR "CORPAUG = $CORPAUG\n";
print STDERR "SourceFlm = $SourceFlm\n";
print STDERR "TargetFlm = $TargetFlm\n";



@Factors = split(/\+/, $CORPAUG);

@NewFactors = ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p');

if (! -e $SourceFlm )
{
  die "file $SourceFlm does not exist!!!";
}

open(SOURCE, "<$SourceFlm");
open(TARGET, ">$TargetFlm");


$j = 0;

while ($radek = <SOURCE>)
{
  chomp($radek);

  if ($j == 1)
  {
		$radek =~ s/[^ ]+\.count\.gz/flm.count.gz/;
    $radek =~ s/[^ ]+\.lm\.gz/flm.lm.gz/;
	}

  for ($i = 0; $i <= $#Factors; $i++)
  {
    $f = $Factors[$i];
    $nf = $NewFactors[$i];

    $radek =~ s/^$f( *:.*)$/$nf$1/;
    $radek =~ s/([\s,])$f([0-9\(])/$1$nf$2/g;
  }

  print TARGET $radek."\n";
  $j++;
}

close SOURCE;
close TARGET;
