#!/usr/bin/env perl
# Tries to detect and fix malformed UTF8 characters.
use utf8;
use Encode;
binmode(STDIN, ':raw');
binmode(STDOUT, ':utf8');
while(<STDIN>)
{
    my $decoded = decode('utf8', $_);
    print($decoded);
}
