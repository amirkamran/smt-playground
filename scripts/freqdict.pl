#!/usr/bin/perl
# Reads tokenized text, writes simple frequency dictionary.
# Copyright © 2009 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

# Read the input.
while(<>)
{
    # Strip the line break.
    s/\r?\n$//;
    # Split tokens.
    my @tokens = split(/\s+/, $_);
    # Note occurrences.
    foreach my $t (@tokens)
    {
        if($t)
        {
            $dictionary{$t}++;
        }
    }
}
# Sort the dictionary in descending order of frequencies.
@words = sort
{
    my $result = $dictionary{$b} <=> $dictionary{$a};
    unless($result)
    {
        $result = $a cmp $b;
    }
    $result;
}
keys(%dictionary);
# Print the words and their frequencies.
foreach my $w (@words)
{
    print("$w\t$dictionary{$w}\n");
}
