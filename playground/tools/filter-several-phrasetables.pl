#!/usr/bin/perl
# run moses sigfilter on several phrase tables

use strict;
use Getopt::Long;
use IPC::Open3;

my ($ws, $srccorp, $tgtcorp, $srcaug, $tgtaug);
my $cutoff=0;
my $threshold=undef;

GetOptions(
  "workspace=s" => \$ws,
  "srccorp=s" => \$srccorp,
  "tgtcorp=s" => \$tgtcorp,
  "srcaug=s" => \$srcaug,
  "tgtaug=s" => \$tgtaug,
  "cutoff=s" => \$cutoff,
  "threshold:s" => \$threshold,
) or exit 1;

if (!defined $threshold || $threshold eq "" || $threshold eq "none") {
  print STDERR "filter-several-phrasetables.pl: No threshold set, doing nothing.";
  exit 0;
}

my $sigfilter = "$ws/moses/sigtest-filter/filter-pt";
my $augment = "$ws/../augmented_corpora/augment.pl";
my $salm_indexer = "$ws/salm-src/Bin/Linux/Index/IndexSA.O64";

die "Can't run $augment" if ! -x $augment;
die "Can't run $sigfilter" if ! -x $sigfilter;

my @infiles = @ARGV;
foreach my $inf (@infiles) {
  # identify source and target factorset of the ttable
  if ($inf =~ /phrase-table\.([0-9,]+)-([0-9,]+)\.gz/) {
    my $srcfactnums = $1;
    my $tgtfactnums = $2;
    my $srccorpindex = call_augment($srccorp, $srcaug, $srcfactnums);
    my $tgtcorpindex = call_augment($tgtcorp, $tgtaug, $tgtfactnums);
    my $renamedinf = $inf;
    $renamedinf =~ s/\.gz$/.unfiltered.gz/;
    safesystem(qw(mv), $inf, $renamedinf)
      or die "Can't move $inf to $renamedinf";
    my $sigfilterargs = "-e $tgtcorpindex -f $srccorpindex -l $threshold -n $cutoff";
    safesystem("zcat $renamedinf | $sigfilter $sigfilterargs | gzip -c > $inf")
      or die "Failed to filter phrases";
    # ensure we got some phrases
    my $testh = my_open($inf);
    my $testline = <$testh>;
    die "Filtered phrase table empty: $inf"
      if !defined $testline;
    close $testh;
  } else {
    die "Failed to get factornums from $inf";
  }
}

sub call_augment {
  my $corp = shift;
  my $namedaug = shift;
  my $wishednums = shift;

  # print STDERR "CORP $corp, NAMEDAUG: $namedaug, WISHEDNUMS: $wishednums\n";

  my @factnames = split /\+/, $namedaug;
  my $lang = shift @factnames;
  my @wishednames = map {
        my $factname = $factnames[$_];
        die "Bad factor number: $_ given $namedaug" if !defined $factname;
        $factname;
      }
      split /,/, $wishednums;
  my $wishednames = join("+", @wishednames);

  print STDERR "Asking augment to construct index for $corp/$lang+$wishednames\n";
  my ($out, $err, $exitcode)
    = saferun3("$augment $corp/$lang+$wishednames"
        ." --suffix-array-index --salm-indexer=$salm_indexer");
  die "Failed to call $augment to obtain salm index"
    ." for $corp/$lang+$wishednames:\nGot STDERR: $err\nGot STDOUT: $out\n"
    if $exitcode != 0;
  my $origout = $out;
  chomp($out);
  # for a reason, we get output and error output combined, get the last line
  $out =~ s/^(\n|.)*\n//;
  print STDERR "Got: $out\n";
  die "Does not look like a valid salm index: $origout"
    if ! -e $out.".sa_suffix";
  return $out;
}



sub saferun3 {
  print STDERR "Executing: @_\n";
  my($wtr, $rdr, $err);
  my $pid = open3($wtr, $rdr, $err, @_);
  close($wtr);
  waitpid($pid, 0);
  my $gotout = "";
  $gotout .= $_ while (<$rdr>);
  close $rdr;
  my $goterr = "";
  $goterr .= $_ while (<$err>);
  close $err if defined $err;
  if ($? == -1) {
      print STDERR "Failed to execute: @_\n  $!\n";
      exit(1);
  }
  elsif ($? & 127) {
      printf STDERR "Execution of: @_\n  died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
      exit(1);
  }
  else {
    my $exitcode = $? >> 8;
    print STDERR "Exit code: $exitcode\n" if $exitcode;
    return ( $gotout, $goterr, $exitcode );
  }
}


sub safesystem {
  print STDERR "Executing: @_\n";
  system(@_);
  if ($? == -1) {
      print STDERR "Failed to execute: @_\n  $!\n";
      exit(1);
  }
  elsif ($? & 127) {
      printf STDERR "Execution of: @_\n  died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
      exit(1);
  }
  else {
    my $exitcode = $? >> 8;
    print STDERR "Exit code: $exitcode\n" if $exitcode;
    return ! $exitcode;
  }
}

sub my_open {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDIN, ":utf8");
    return *STDIN;
  }

  die "Not found: $f" if ! -e $f;

  my $opn;
  my $hdl;
  my $ft = `file '$f'`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat '$f' |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat '$f' |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

