#!/usr/bin/perl -CSAD
# Manages existing experiments, etc.

use strict;
use Getopt::Long;
use File::Basename;
use File::Path;
use Digest::MD5 qw(md5_hex);

my @keywordfile = qw/DONE FAILED OUTDATED/;

my $vars = 0;
my $log = 0;
my $debug = 0;
my $reindex = 0;
my $indexfile = "index.exps";
my @substitute = ();
my @avoid = ();
my $nosubmit = 0;
my $redo = 0;
my $cleanup = 0;
my $guess = 0;
my $showtag = 0;
my $do_run = 1;
GetOptions(
  "vars" => \$vars, # print experiment vars in traceback mode
  "log" => \$log, # print experiment log in traceback mode
  "debug" => \$debug,
  "n|nosubmit" => \$nosubmit,
  "run!" => \$do_run, # do start the experiment
  "reindex!" => \$reindex, # refresh md5 sums of all experiments (defaults to 1, use --no-reindex)
  "s|substitute=s@" => \@substitute, # derive an experiment chain from existing
                          # ones using a regex: --s=/form/lc/g
  "redo" => \$redo, # force experiment derivation with no change using --s
  "guess" => \$guess, # just guess experiment directory
  "cleanup" => \$cleanup, # just print unused experiments
  "showtag" => \$showtag, # show tag in traceback
  "a|avoid=s@" => \@avoid, # avoid these subexperiments
) or exit 1;

my %avoid = map { ( $_, 1 ) } @avoid;

# update md5 indices
my $idx = loadidx() unless $reindex; # ignore saved values
my @dirs = glob("exp.*.*.[0-9]*");
foreach my $d (@dirs) {
  next if defined $idx->{$d};
  next if ! experiment_valid($d);
  my $hash = get_hash_from_dir($d);
  $idx->{$d} = $hash;
  $idx->{$hash} = $d;
  print STDERR "$d: $idx->{$d}\n" if $debug;
}
saveidx($idx);

if ($guess) {
  # just guessing experiment directories
  foreach my $key (@ARGV) {
    my $exp = guess_exp($key);
    print $exp."\n";
  }
  exit 0;
}

if ($cleanup) {
  # just cleaning up
  # construct a queue of needed experiments, starting from merts
  my %needed = map { ($_, 1) } grep { /^exp\.mert\./ } @dirs;
  my @q = keys %needed;
  while (my $e = shift @q) {
    next if ! -d $e; # ignore deps of nonexisting experiments
    my @deps = split /\n/, load($e."/deps");
    push @q, @deps;
    foreach my $d (@deps) {
      $needed{$d} = 1;
    }
  }
  # print all but needed exps
  print STDERR "Listing unused experiments.\n";
  foreach my $e (@dirs) {
    next if $needed{$e};
    print $e."\n";
  }
  exit 0;
}

if ($redo || 0 < scalar @substitute) {
  # derive an experiment using a key (from arg)
  foreach my $key (@ARGV) {
    my $exp = guess_exp($key);
    my %deps = ();
    my $outexp = derive_exp($exp, \%deps);
    if ($outexp eq $exp) {
      print STDERR "No change in $exp\n";
    } elsif ($nosubmit) {
      print STDERR "Not submitting any experiments, as you wished.\n";
    } else {
      # submit all the jobs as necessary, including dependencies
      foreach my $e (@{$deps{"TOPOLOGICAL"}}) {
        next if -e $e."/DONE";
        die "Prerequisite $e failed." if -e $e."/FAIL";
        next if -e $e."/log"; # assume the experiment has already started

        # convert each prerequisite name to jobid
        my @holds = ();
        foreach my $prereq (@{$deps{$e}}) {
          next if -e $prereq."/DONE"; # skip finished prereqs
          my $prereqid = get_exp_jobid($prereq);
          die "Failed to get jobid of $prereq" if !defined $prereqid;
          push @holds, $prereqid;
        }
        # construct holds string of all prereq.jobs
        my $holds = @holds ? join(" ", map {"-hold=$_"} @holds) : "";

        my $oldholds = $ENV{"HOLDS"};
        $oldholds ||= "";
        print STDERR "OLD HOLDs: $oldholds\n";
        print STDERR "HOLDs: $holds\n";

        my $runval = $do_run ? "yes" : "no";
        safesystem("RUN=$runval HOLDS='$oldholds $holds' make $e.prep_inited") or die;
      }
    }
    traceback("SRC ", $exp);
    traceback("NEW ", $outexp);
  }
  exit 0;
}

foreach my $key (@ARGV) {
  # traceback an experiment given a seed key
  my $exp = guess_exp($key);
  traceback("", $exp);
}

sub get_exp_jobid {
  my $exp = shift;
  die "Not an experiment: $exp" if ! -d $exp;

  my $hdl = my_open($exp."/log");
  my $nl = 0;
  my $jid = undef;
  while(<$hdl>) {
    $nl++;
    last if $nl > 10;
    if (/Your job ([0-9]+) .*has been submitted/) {
      $jid = $1;
      last;
    }
  }
  close $hdl;
  return $jid; # possibly undef
}

sub derive_exp {
  my $exp = shift;
  my $deps = shift;

  my @mydeps = ();

  # print STDERR "Deriving from $exp\n" if $debug;

  # load vars and sources
  my @oldvars = split /\n/, load($exp."/VARS");
  my @oldsources = split /\n/, load($exp."/deps");
  my @vars = @oldvars;

  # derive experiments for sources and replace sources with new ones in vars
  my @sources = ();
  foreach my $s (@oldsources) {
    my $news = derive_exp($s, $deps);
    if ($news ne $s) {
      # print STDERR "Need to replace $s with $news\n" if $debug;
      @vars = map { s/\Q$s\E/$news/g; $_; } @vars; # use the new one in vars
      # print STDERR "New vars: @vars\n" if $debug;
    }
    push @sources, $news;
    push @mydeps, $news; # our newly created experiment can be launched only after the source
  }

  # apply the regexp to vars
  foreach my $substitute (@substitute) {
    @vars = map { eval "s$substitute"; $_; } @vars;
  }
  @vars = sort @vars;
  @oldvars = sort @oldvars;
  @sources = sort @sources;
  @oldsources = sort @oldsources;

  # check if we changed (or the source failed or is outdated) and possibly init us
  my $newexp = $exp;
  if ("@vars" ne "@oldvars" || "@sources" ne "@oldsources"
    || ! experiment_valid($exp)) {
    # print vars and how they change
    if ($debug) {
      print STDERR "Modifying EXP $exp to:\n";
      for(my $v=0; $v<@oldvars; $v++) {
        print STDERR $vars[$v];
        print STDERR "\t<--   $oldvars[$v]" if $oldvars[$v] ne $vars[$v];
        print STDERR "\n";
      }
      print STDERR "\n";
    }

    # check if there is such an experiment already
    my $hash = get_hash_from_vars_deps(\@vars, \@sources);
    if (defined $idx->{$hash}
        && -d $idx->{$hash}
        && experiment_valid($idx->{$hash})
        ) {
      $newexp = $idx->{$hash};
      print STDERR "Reusing existing experiment: $newexp\n";
    } else {
      # Init the modified experiment
      $exp =~ /^exp\.([^.]+)/ || die "Failed to get exp type from $exp";
      my $exptype = $1;
      my $cmd = "@vars make exp.$exptype.init\n";
      print STDERR "$cmd\n";
      $newexp = `$cmd`;
      chomp $newexp;
      die "Failed to init a new exp, got: $newexp" if ! -d $newexp;
      print STDERR "Inited new experiment: $newexp\n";
      print STDERR "  with deps: @mydeps\n";
    }
  } else {
    if ($debug) {
      print STDERR "No change in EXP $exp\n";
    }
  }
  push @{$deps->{"TOPOLOGICAL"}}, $newexp; # sort right away
  push @{$deps->{$newexp}}, @mydeps;
  return $newexp;
}

sub experiment_valid {
  my $exp = shift;
  return -d $exp 
    && ! -e "$exp/FAILED" 
    && ! -e "$exp/OUTDATED"
    && ! $avoid{$exp}; # forbidden on commandline
}

sub traceback {
  my $prefix = shift;
  my $exp = shift;
  print "$prefix+- $exp\n";
  my @kws;
  my $jid = get_exp_jobid($exp);
  push @kws, $jid if defined $jid;
  foreach my $kwfile (@keywordfile) {
    push @kws, $kwfile if -e $exp."/$kwfile";
  }
  if ($showtag) {
    my $tag = `cat $exp/TAG 2>/dev/null`; chomp $tag;
    push @kws, $tag if defined $tag && $tag ne "";
  }
  print "$prefix|  | Job: @kws\n";
  if ($vars) {
    my $v = load($exp."/VARS");
    foreach my $l (split /\n/, $v) {
      print "$prefix|  | $l\n";
    }
  }
  if ($log) {
    my $logtext = `tail -n3 $exp/log.* 2> /dev/null`;
    chomp $logtext;
    foreach my $l (split /\n/, $logtext) {
      print "$prefix|  | $l\n";
    }
  }
  my $deps = load($exp."/deps");
  foreach my $dep (split /\n/, $deps) {
    traceback("$prefix|  ", $dep);
  }
}

sub guess_exp {
  my $key = shift;
  my $exp = confirm_exp($key);
  if (!defined $exp) {
    # guess from bleu file
    my $bleufile = load("bleu");
    
    my @bleumatches = grep { /$key/ } split /\n/, $bleufile;
    if (1<scalar(@bleumatches)) {
      print STDERR "Ambiguous in bleu file: $key:\n";
      print STDERR join("", map { "  $_\n" } @bleumatches);
      exit 1;
    }
    
    print STDERR scalar(@bleumatches)." matches in bleu file\n" if $debug;
    if (1==scalar @bleumatches) {
      my $f = field($bleumatches[0], 1);
      $f =~ s/\<.*//;
      $exp = confirm_exp($f);
    }
  }
  if (!defined $exp) {
    # guess from dir listing
    my @dirs = grep { /$key/ } glob("exp.*.*.[0-9]*");
    if (1<scalar(@dirs)) {
      print STDERR "Ambiguous in dir listing: $key:\n";
      print STDERR join("", map { "  $_\n" } @dirs);
      exit 1;
    }
    $exp = confirm_exp($dirs[0]) if 1==scalar @dirs;
  }
  die "Failed to guess exp from: $key" if !defined $exp;
  return $exp;
}  

sub confirm_exp {
  my $key = shift;
  print STDERR "Confirming $key\n" if $debug;
  return $key if -d $key;
  foreach my $pref (qw/exp.eval. exp.mert. exp.model. exp.2step./) {
    if (-d $pref.$key) {
      return $pref.$key;
    }
  }
  return undef; #couldn't confirm
}

sub load {
  my $f = shift;
  my $h = my_open($f);
  my $o = "";
  $o .= $_ while (<$h>);
  close $h;
  chomp $o;
  return $o;
}

sub loadidx {
  # load the index file and hash it there and back
  my %idx;
  if (-e $indexfile) {
    %idx = map { my ($d, $md5) = split /\t/; ($d, $md5, $md5, $d) }
             split /\n/, load($indexfile);
  }
  return \%idx;
}
sub saveidx {
  my $idx = shift;
  my $h = my_save($indexfile);
  foreach my $k (keys %$idx) {
    print $h "$k\t$idx->{$k}\n";
  }
  close $h;
}

sub get_hash_from_dir {
  my $exp = shift;

  my @vars = split /\n/, load($exp."/VARS");
  my @deps = split /\n/, load($exp."/deps");
  return md5_hex(sort @vars, sort @deps);
}
sub get_hash_from_vars_deps {
  my $vars = shift;
  my $deps = shift;
  return md5_hex(sort @$vars, sort @$deps);
}

sub field {
  my $l = shift;
  my $i = shift;
  chomp $l;
  my @f = split /\t/, $l;
  return $f[$i];
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

sub my_save {
  my $f = shift;

  my $opn;
  my $hdl;
  # file might not recognize some files!
  if ($f =~ /\.gz$/) {
    $opn = "| gzip -c > $f";
  } elsif ($f =~ /\.bz2$/) {
    $opn = "| bzip2 > $f";
  } else {
    $opn = "> $f";
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
