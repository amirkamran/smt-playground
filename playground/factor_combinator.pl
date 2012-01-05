#!/usr/bin/perl
# Given any number of triples of arguments "filename column factor"
# constructs a combined file with factors in that order.
# Dies if line or factor counts are not compatible.

use strict;


binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");


my @wishes;

my %fname_to_stream;
my %fname_to_columns;

while (0 < scalar @ARGV) {
  my $fname = shift;
  my $column = shift;
  my $factor = shift;
  die "Bad usage!" if $column !~ /^-?[0-9]+$/ || $factor !~ /^-?[0-9]+$/;
  $fname_to_stream{$fname} = my_open($fname);
  $fname_to_columns{$fname}->{$column} = 1;
  push @wishes, [$fname, $column, $factor];
}

die "Nothing to do." if 0 == scalar @wishes;

my $nr=0;
while (1) {
  # read lines from all inputs
  $nr++;
  print STDERR "." if $nr % 10000 == 0;
  print STDERR "($nr)" if $nr % 100000 == 0;
  chomp;
  # load lines of corresponding streams and ensure equal number of words
  my $fnamecol_to_line = undef;
  my $words_per_line = undef;
  my $got_a_line = 0;
  foreach my $fname (keys %fname_to_stream) {
    my $line = readline($fname_to_stream{$fname});
    die "$fname:$nr:File too short!"
      if !defined $line && $got_a_line;
    $got_a_line = 1;
    chomp($line);
    my $splitline = undef;
    foreach my $column (keys %{$fname_to_columns{$fname}}) {
      my $sentence;
      if ($column == -1) {
        $sentence = $line;
      } else {
        $splitline = [ split /\t/, $line ] if !defined $splitline;
        $sentence = $splitline->[$column-1];
      }
      my @toks = split / +/, $sentence;
      my $this_words_per_line = scalar(@toks);
      die "$fname:$nr:column$column:Mismatching word count, expected $words_per_line, got $this_words_per_line"
        if defined $words_per_line && $words_per_line != $this_words_per_line;
      $words_per_line = $this_words_per_line;
      $fnamecol_to_line->{$fname}->{$column} = [ map { [ split /\|/, $_ ] } @toks ];
    }
  }
  last if 0 == $got_a_line;

  # for every token, print the factors in the order as user wished
  for(my $i=0; $i<$words_per_line; $i++) {
    my @outtoken = ();
    foreach my $wish (@wishes) {
      my ($fname, $column, $factor) = @$wish;
      my $f = $fnamecol_to_line->{$fname}->{$column}->[$i]->[$factor];
      die "$fname:$nr:Missed or blank factor $factor of word ".($i+1)
          if !defined $f || $f eq "";
      push @outtoken, $f;
    }
    print " " if $i != 0;
    print join("|", @outtoken);
  }
  print "\n";
}

foreach my $stream (values %fname_to_stream) {
  close $stream;
}



sub my_open {
  my $f = shift;
  die "Not found: $f" if ! -e $f;

  my $opn;
  my $hdl;
  my $ft = `file $f`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat $f |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat $f |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

