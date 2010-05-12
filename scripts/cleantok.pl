#!/usr/bin/perl
# Cleans tokenization format (spaces, line breaks).
# Does not change tokenization proper.
# Does not perform actions requiring parallel processing of both languages (e.g. blank lines removal).
# Copyright © 2010 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    # Remove the line break.
    # If it is Windows-style (CR LF), it will be later replaced by Linux-style (LF).
    # Windows-style line breaks could make GIZA++ crash.
    # If the last line does not have a line break (could cause 'wc -l' not to count it) it will get one.
    s/\r?\n$//;
    # Remove superfluous spaces at the beginning and end of the line.
    s/^\s+//;
    s/\s+$//;
    # Change all tabs and other blank characters to normal spaces.
    # Reduce any sequence of spaces to one space.
    # It could be interpreted as an empty token and corrupt format of phrase table or other files.
    s/\s+/ /g;
    # We cannot remove blank lines but we can warn the user about them.
    if($_ eq '')
    {
        $n_blank++;
    }
    # Add a new Linux-style line break.
    # Note that Perl might expand "\n" to "\r\n" if running in Windows, so chr(10) is safer.
    $_ .= chr(10);
    print;
}
if($n_blank)
{
    print STDERR ("WARNING: There are $n_blank blank lines.\n");
    print STDERR ("They should be removed together with their counterparts in other languages.\n");
}
