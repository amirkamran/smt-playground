#!/usr/bin/perl
# This script splits UTF8 input down to characters and prints their codes and properties, one-char-per-line.
# Copyright © 2008 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use charnames ();

while(<>)
{
    my @chars = split(//, $_);
    foreach my $char (@chars)
    {
        my $properties;
        foreach my $prop qw(L M N P S Z C)
        {
            if($char =~ m/\p$prop/)
            {
                $properties .= $prop;
            }
        }
        my $code = ord($char);
        my $name = charnames::viacode($code);
        printf("$char\t%5d\t%04X\t$properties\t$name\n", $code, $code);
    }
}
