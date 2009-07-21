#!/usr/bin/perl
# Convert a huge listing of all results into several nice 2D tables.
# The conversion rules are loaded from a given config file.

use strict;
use Summarizer;
use File::Basename;
use File::Path;
use File::Spec;
use Getopt::Long qw(GetOptionsFromString);

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

my $mypath = File::Spec->rel2abs(__FILE__);
my $basedir = dirname($mypath);
my $scriptname = basename($mypath);

my $configfile;
my @optionspecs = (
  "f|config=s"=>\$configfile,
);

# use default options from ./augment.pl.flags, if available
my $default_opt_file = "$basedir/$scriptname.flags";
if (-e $default_opt_file) {
  print STDERR "Loading default options from $default_opt_file\n";
  my $h = my_open($default_opt_file);
  my $defaultoptstr = "";
  $defaultoptstr .= $_ while <$h>;
  close $h;
  GetOptionsFromString($defaultoptstr, @optionspecs)
    or die "Bad options in $default_opt_file";
  $configfile = File::Spec->rel2abs($configfile, dirname($default_opt_file));
}

GetOptions(@optionspecs) or exit 1;

die "usage: $0 -f config.pl" if ! defined $configfile;
my $config = require($configfile);

die "Bad config in $configfile" if ! defined $config;

my $data = Summarizer::load(*STDIN);

foreach my $scan (@$config) {
  my ($title, $subtitle, $req, $forb, $col, $rows, $cols, $sortcol, $verbose, $tokenmap)
    = @$scan;
  Summarizer::newscan(
    {
      title=>$title,
      subtitle=>$subtitle,
      reqtoks=>$req,
      forbtoks=>$forb,
      col=>$col,
      rowtoks=>$rows,
      coltoks=>$cols,
      sortcol=>$sortcol,
      verbose=>$verbose,
      tokenmap=>$tokenmap,
    },
    $data);
}

# end of main
exit 0;



sub my_open {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDIN, ":utf8");
    return *STDIN;
  }

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
