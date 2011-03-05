#!/usr/bin/perl -w
# reads factored text and further tokenizes things like '30kg', 'anglo-american'
# aimed for English or Czech
# never split "&entity;"

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use utf8; # this script is in utf8

use strict;

my $factor = 0; # split based on this factor, copy all others

while (<>) {
  chomp;
  my @toks = split / /;
  my @outtoks = ();
  foreach my $tok (@toks) {
    my @facts = split /\|/, $tok;
    my $f = $facts[$factor];
    my $split = split_factor($facts[$factor]);
    if (defined $split) {
      foreach my $part (@$split) {
        $facts[$factor] = $part;
        push @outtoks, join("|", @facts);
      }
    } else {
      push @outtoks, $tok;
    }
  }
  print join(" ", @outtoks)."\n";
}

sub split_punct_unless_identical {
  my $s = shift;
  my @out = ();
  my $lastc = undef;
  foreach my $c (split //, $s) {
    if (defined $lastc && $c ne $lastc) {
      push @out, " $c";
    } else {
      push @out, $c
    }
    $lastc = $c;
  }
  return join("", @out);
}

sub split_factor {
  my $s = shift;
  return undef if $s =~ /^.$/;  # nothing to split in singlechars
  return undef if $s =~ /^[[:alpha:]]*$/;
  return undef if $s =~ /^[[:digit:]]*$/;
  return undef if $s =~ /^[-+]?[[:digit:],.]+$/;

  # unescape
  $s =~ s/&pipe;/|/g;
  $s =~ s/&space;/ /g;  # get rid of David's multiword tokens
  $s =~ s/&amp;/&/g;

  $s =~ s/([[:digit:][:punct:]\p{S}])([[:alpha:]])/$1 $2/g;
  $s =~ s/([[:alpha:][:punct:]\p{S}])([[:digit:]])/$1 $2/g;
  $s =~ s/([[:alpha:][:digit:]\p{S}])([[:punct:]])/$1 $2/g;
  $s =~ s/([[:alpha:][:digit:][:punct:]])([\p{S}])/$1 $2/g;

  $s =~ s/([[:alpha:]])([[:digit:][:punct:]\p{S}])/$1 $2/g;
  $s =~ s/([[:digit:]])([[:alpha:][:punct:]\p{S}])/$1 $2/g;
  $s =~ s/([[:punct:]])([[:alpha:][:digit:]\p{S}])/$1 $2/g;
  $s =~ s/([\p{S}])([[:alpha:][:digit:][:punct:]])/$1 $2/g;

  # each punct symbol on its own unless they are two identical in a row
  $s =~ s/([[:punct:]][[:punct:]]+)/split_punct_unless_identical($1)/ge;

  # escape
  $s =~ s/&/&amp;/g;
  $s =~ s/\|/&pipe;/g;

  return [ split / /, $s];
}
