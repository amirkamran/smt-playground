#!/usr/bin/perl
# Reads English stc|lemma|tag (and optionally |toclass).
# Trains or applies maxent classifier to predict the toclass for all tokens
# with stc=="to"

# Prints nothing (training mode) or the toclasses (test mode) as factored
# output.

use strict;
use Getopt::Long;
use File::Temp qw /tempdir/;
use File::Path;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $maxent = "/net/tmp/bojar/wmt13-bojar/src/maxent/src/opt/maxent";
my $print_help = 0;
my $do_train = 0;
my $keep = 0;
my $tempdir = "/mnt/h/tmp";
GetOptions(
  "help" => \$print_help,
  "train" => \$do_train,
  "tempdir=s" => \$tempdir,
  "maxent=s" => \$maxent,
  "keep" => \$keep,
) or exit 1;

my $tmp = tempdir("toclassXXXX", CLEANUP=>0, DIR=>$tempdir);
print STDERR "My tempdir: $tmp\n";
my $tempfile = "$tmp/temp";

my $do_predict = !$do_train;

my $modelfile = shift;

die "usage: $0 modelfile [--train] < stc|lemma|tag > predicted-toclass"
  if !defined $modelfile;

# Read the input, construct eventfile with features
#   In training mode, this tempfile will contain the correct class.
# In prediction mode, store also where the template for the output (which
# tokens get a predicted value, which do not)
my $eventh = my_save($tempfile.".events");
my $templateh = my_save($tempfile.".outtoks") if $do_predict;
my $nr = 0;
while (<>) {
  $nr++;
  print STDERR "." if $nr % 100000 == 0;
  print STDERR "($nr)" if $nr % 1000000 == 0;
  chomp;
  my @intoks = split / /, trim($_);

  # split tokens into factors for further use
  my @tokens = ();
  foreach my $token (@intoks) {
    my @facts = split /\|/, $token;
    my ($stc, $lemma, $tag, $mayclass) = @facts;
    die "$nr:Bad input token: $token"
      if !defined $tag || !defined $stc || !defined $lemma;
    die "$nr:Training mode but not class: $token"
      if $do_train && !defined $mayclass;
    push @tokens, [@facts];
  }
  # process tokens
  my @outtoks = ();
  for (my $i=0; $i<@tokens; $i++) {
    my $token = $tokens[$i];
    my ($stc, $lemma, $tag, $mayclass) = @$token;
    $mayclass = "?" if $do_predict;
    if ($stc eq "to") {
      # our target word!
      push @outtoks, "?" if $do_predict; # prepare the template
      # prepare the features
      my %features = ();
      for my $d (-3..-1,1..3) {
        my $lem;
        if ($i+$d >= 0 && $i+$d < @tokens) {
          $lem = $tokens[$i+$d]->[1];
          $lem = "<undef>" if !defined $lem;
        } else  {
          $lem = "<undef>";
        }
        $features{"lem$d:$lem"} = 1;
        $features{"lembef:$lem"} = 1 if $d < 0;
        $features{"lemaft:$lem"} = 1 if $d > 0;
        my $tg;
        if ($i+$d >= 0 && $i+$d < @tokens) {
          $tg = $tokens[$i+$d]->[2];
          $tg = "<undef>" if !defined $tg;
        } else  {
          $tg = "<undef>";
        }
        $features{"tag$d:$tg"} = 1;
        $features{"tagbef:$tg"} = 1 if $d < 0;
        $features{"tagaft:$tg"} = 1 if $d > 0;
      }
      # emit the event
      print $eventh $mayclass, "\t", join("\t", keys %features), "\n";
    } else {
      push @outtoks, "-" if $do_predict;
    }
  }
  die "$nr:Nonsense: mismatched number of intoks and outtoks:\n@intoks\n@outtoks\n@tokens\n"
    if $do_predict && scalar(@intoks) != scalar(@outtoks);
  print $templateh join(" ", @outtoks), "\n" if $do_predict;
}
print STDERR "Processed $nr events.\n";
close($templateh) if $do_predict;
close($eventh);

# run maxent
if ($do_train) {
  safesystem("$maxent $tempfile.events --model='$modelfile' --binary --gis 1>&2")
    or die "Failed to train the model";
} else {
  # do predict
  safesystem("$maxent $tempfile.events --model='$modelfile' --binary --predict --output=$tempfile.predicted 1>&2")
    or die "Failed to predict";

  print STDERR "Printing linearized output to stdout.\n";
  # implant predictions into the prepared template and emit to stdout
  my $predsh = my_open("$tempfile.predicted");
  my $templateh = my_open("$tempfile.outtoks");
  while (<$templateh>) {
    chomp;
    my @toks = split / /;
    for (my $i=0; $i<@toks; $i++) {
      print " " if $i > 0;
      if ($toks[$i] eq "-") {
        print "-";
      } else {
        my $prediction = <$predsh>;
        die "Predictions file too short: $tempfile.predicted"
          if ! defined $prediction;
        chomp $prediction;
        print $prediction;
      }
    }
    print "\n";
  }
  close $predsh;
  close $templateh;
}

if ($keep) {
  print STDERR "Keeping $tmp, delete yourself.\n";
} else {
  rmtree($tmp);
}


sub trim {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
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

use File::Path;
use File::Basename;
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
