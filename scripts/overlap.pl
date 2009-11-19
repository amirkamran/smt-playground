#!/usr/bin/perl
# Načte postupně dva korpusy a zjistí, kolik vět druhého je obsaženo v prvním.
# Je určeno pro jednojazyčnou polovinu paralelního korpusu, kde každý řádek odpovídá jedné větě (segmentu).
# Copyright © 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

sub usage
{
    print STDERR ("Užití: overlap.pl corpus1 corpus2\n");
}

unless(scalar(@ARGV)==2)
{
    usage();
    die("Chybný počet argumentů.\n");
}
$handle = my_open($ARGV[0]);
while(<$handle>)
{
    $hash{$_}++;
}
close($handle);
$handle = my_open($ARGV[1]);
while(<$handle>)
{
    if(exists($hash{$_}))
    {
        print;
    }
}
close($handle);



#------------------------------------------------------------------------------
# Ondřejovo open si poradí i se zagzipovanými soubory.
#------------------------------------------------------------------------------
sub my_open
{
    my $f = shift;
    die "Not found: $f" if ! -e $f;
    my $opn;
    my $hdl;
    my $ft = `file $f`;
    # file might not recognize some files!
    if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/)
    {
        $opn = "zcat $f |";
    }
    elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/)
    {
        $opn = "bzcat $f |";
    }
    else
    {
        $opn = "$f";
    }
    open $hdl, $opn or die "Can't open '$opn': $!";
    binmode $hdl, ":utf8";
    return $hdl;
}
