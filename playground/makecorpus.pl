#!/usr/bin/perl
# This script cooperates with eman.seeds/makecorpus (and possibly other eman
# seeds) and constructs factored corpus of a given specification within eman
# framework of steps.

use strict;

use Getopt::Long;
use File::Path;
use File::Basename;

my $verbose = 0;

my $descr = shift;

if (! defined $descr) {
  print STDERR "usage: $0 corpname/lang+fact1+fact2+fact3
Find or construct a factored corpus given a corpus description.
Allowed corpus descriptions:
   corpname/lang+fact1+fact2
     ... use the corpus 'corpname' in the language 'lang' and extend it with
         factors labelled fact1 and fact2
   corp1+corp2/lang+fact1+fact2
     ... concatenate the language lang of corpus 1 and 2 and emit the wished
         factors
";
  exit 1;
}


# first construct an index of corpora bits
my $index;
# $index->{corpname}->{language}->{fact}
#    = {   stepname=>the_directory_name,
#          filename=>filename_within_the_stepname,
#          column=>column_within_the_file; -1 could indicate the whole file,
#          factind=>factor_index_within_the_file, -1 indicates the whole file
#          linecount=>number_of_lines}
# where 'fact' *can* be a specification of several factors: 
my $err = 0;

# XXX chdir to main dir
open INDFILES, "find -name corpman.info |" or die "Can't search for corpora";
while (<INDFILES>) {
  chomp;
  my $fn = $_;
  my @dirs = split /\//, $fn, 2;
  my $stepname = undef;
  foreach my $dir (split /\//, $fn) {
    if ($dir =~ /^s\..*\.[0-9]{8}-[0-9]{4}$/) {
      $stepname = $dir;
      last;
    }
  }
  die "Failed to guess step name from $fn" if !defined $stepname;
  my $status = load_file($stepname."/eman.status");
  next if $status !~ /INITED|PREPARED|RUNNING|WAITING|DONE/;
    # skip all bad steps
  my $text = load_file($fn);
  foreach my $line (split /\n/, $text) {
    next if $line eq "";
    my ($filename, $column, $corpname, $lang, $facts, $linecount)
      = split /\t/, $line;
    die "Bad entry $fn: $line" if $linecount !~ /^[0-9]+$/;

    add_entry($corpname, $lang, $facts, {
      "stepname" => $stepname,
      "filename" => $filename,
      "column" => $column,
      "factind" => -1,
      "linecount" => $linecount,
    });

    if ($facts =~ /[+\|]/) {
      # add also individual factors to support construction of the corpus
      my $factind = -1;
      foreach my $fact (split /[+\|]/, $facts) {
        $factind++;
        add_entry($corpname, $lang, $fact, {
          "stepname" => $stepname,
          "filename" => $filename,
          "column" => $column,
          "factind" => $factind,
          "linecount" => $linecount,
        });
      }
    }
  }
}
close INDFILES;

exit 1 if $err;

my $corp;
my $lang;
my $facts;
if ($descr =~ /^(.+?)\/(.+?)\+(.*)$/) {
  $corp = $1;
  $lang = $2;
  $facts = $3;
} else {
 die "Bad descr format: $descr";
}

# now check if the whole corpus wish happens to be ready
my $entry = $index->{$corp}->{$lang}->{$facts};
if (defined $entry && $entry->{"factind"} == -1) {
  print $entry->{"stepname"}, "\t", $entry->{"filename"}, "\t",
    $entry->{"column"}, "\n";
  exit 0;
}

# need to construct corpus from parts

# read rules from makecorpus.rules
my $rulestext = load_file("makecorpus.rules");

my $rule;
# $rule->{outlang}->{outfacts} = {
#   inlang=>input language
#   infacts=>input factors
# }



# first ensure we can prepare all necessary parts
# allow direct application factor->factor rules
# allow also indirect manyfactors->manyfactors + restrict (in two eman steps)
#   ... and recursively search for the prerequisites




sub add_entry {
  # Add a corpus to the index avoiding duplicates.
  # This *could* be restricted by some other variables like eman select...
  my ($corpname, $lang, $fact, $newentry) = @_;

  print STDERR "Adding $corpname/$lang+$fact: "
      ."$newentry->{stepname}/$newentry->{filename}:$newentry->{column}"
      ."\n" if $verbose;
  my $oldentry = $index->{$corpname}->{$lang}->{$fact};
  if (defined $oldentry) {
    print STDERR "Conflicing sources for $corpname/$lang+$fact: "
      ."$newentry->{stepname}/$newentry->{filename}:$newentry->{column}"
      ." vs "
      ."$oldentry->{stepname}/$oldentry->{filename}:$oldentry->{column}\n";
    $err = 1;
  } else {
    $index->{$corpname}->{$lang}->{$fact} = $newentry;
  }
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


# Run a command very safely.
# Synopsis: safesystem(qw(echo hello)) or die;
sub safesystem {
    # print STDERR "Executing: @_\n";
    system(@_);
    if ($? == -1) {
        print STDERR "Failed to execute: @_\n  $!\n";
        exit(1);
    } elsif ($? & 127) {
        printf STDERR "Execution of: @_\n  died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
        exit(1);
    } else {
        my $exitcode = $? >> 8;
        print STDERR "Exit code: $exitcode\n" if $exitcode;
        return ! $exitcode;
    }
}

sub my_save {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDOUT, ":utf8");
    return *STDOUT;
  }

  my $opn;
  my $hdl;
  # file might not recognize some files!
  if ($f =~ /\.gz$/) {
    $opn = "| gzip -c > '$f'";
  } elsif ($f =~ /\.bz2$/) {
    $opn = "| bzip2 > '$f'";
  } else {
    $opn = ">$f";
  }
  mkpath( dirname($f) );
  open $hdl, $opn or die "Can't write to '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

sub load_file {
  my $fn = shift;
  my $out = "";
  my $h = my_open($fn);
  $out .= $_ while <$h>;
  close $h if $fn ne "-";
  return $out;
}

sub save_file {
  my $fn = shift;
  my $text = shift;
  my $h = my_save($fn);
  print $h $text;
  close $h;
}
