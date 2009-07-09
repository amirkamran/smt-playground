#!/usr/bin/env perl
# Manages existing experiments, etc.

use strict;
use Getopt::Long;
use File::Basename;
use File::Path;
use Digest::MD5 qw(md5_hex);

my $vars = 0;
my $debug = 0;
my $reindex = 0;
my $force = 0;
my $indexfile = "index.exps";
my $derive = undef;
GetOptions(
  "vars" => \$vars, # print experiment vars in traceback mode
  "debug" => \$debug,
  "reindex" => \$reindex, # collect md5 sums of experiments
  "force" => \$force, # reindex everything
  "derive=s" => \$derive, # derive an experiment chain from existing ones
                          # using a regex: --derive=/form/lc/g
) or exit 1;

if ($reindex) {
  my $idx = loadidx() unless $force;
  my @dirs = glob("exp.*.*.[0-9]*");
  foreach my $d (@dirs) {
    next if defined $idx->{$d};
    $idx->{$d} = get_hash_from_dir($d);
    print STDERR "$d: $idx->{$d}\n";
  }
  saveidx($idx);
}

if (defined $derive) {
  # derive an experiment using a key (from arg)
  foreach my $key (@ARGV) {
    my $exp = guess_exp($key);
    my %deps = ();
    my $outexp = derive_exp($exp, \%deps);
    if ($outexp eq $exp) {
      print STDERR "No change in $exp\n";
    } else {
      # submit all the jobs as necessary, including dependencies
      foreach my $e (@{$deps{"TOPOLOGICAL"}}) {
        next if -e $e."/DONE";
        die "Prerequisite $e failed." if -e $e."/FAIL";

        # convert each prerequisite name to jobid
        my @holds = ();
        foreach my $prereq (@{$deps{$e}}) {
          next if -e $prereq."/DONE"; # skip finished prereqs
          my $prereqid = get_exp_jobid($prereq);
          push @holds, $prereqid;
        }
        my $holds = @holds ? "-hold_jid ".join(",", @holds) : "";

        # construct holds string of all prereq.jobs
        die "XXX";
        safesystem("HOLDS='$holds' make $e.prepare_inited_and_submit") or die;
      }
    }
  }

}

foreach my $key (@ARGV) {
  # traceback an experiment given a seed key
  my $exp = guess_exp($key);
  traceback("", $exp);
}

sub derive_exp {
  my $exp = shift;
  my $deps = shift;

  # load vars and sources
  my @oldvars = split /\n/, load($exp."/VARS");
  my @oldsources = split /\n/, load($exp."/deps");

  # apply the regexp to vars
  my @vars = map { eval "s$derive"; $_; } @oldvars;

  # derive experiments for sources and replace sources with new ones in vars
  my @sources = ();
  foreach my $s (@oldsources) {
    my $news = derive_exp($s, $deps);
    if ($news ne $s) {
      push @{$deps->{$exp}}, $news; # we rely on the new one
      @vars = map { s/$s/$news/g; $_ } @vars; # use the new one in vars
    }
    push @sources, $news;
  }

  # check if we changed and possibly init us
  my $newexp = $exp;
  if ("@vars" ne "@oldvars" || "@sources" ne "@oldsources") {
    print STDERR "@vars make exp.XXX.init";
    $newexp = "XXX";
  }
  push @{$deps->{"TOPOLOGICAL"}}, $newexp; # sort right away
  return $newexp;
}

sub traceback {
  my $prefix = shift;
  my $exp = shift;
  print "$prefix+- $exp\n";
  if ($vars) {
    my $v = load($exp."/VARS");
    foreach my $l (split /\n/, $v) {
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
    die "Ambiguous in bleu file: $key" if 1<scalar(@bleumatches);
    
    print STDERR scalar(@bleumatches)." matches in bleu file\n" if $debug;
    if (1==scalar @bleumatches) {
      my $f = field($bleumatches[0], 1);
      $f =~ s/<.*//;
      $exp = confirm_exp($f);
    }
  }
  if (!defined $exp) {
    # guess from dir listing
    my @dirs = grep { /$key/ } glob("exp.*.*.[0-9]*");
    die "Ambiguous in dir listing: $key" if 1<scalar(@dirs);
    $exp = confirm_exp($dirs[0]) if 1==scalar @dirs;
  }
  die "Failed to guess exp from: $key" if !defined $exp;
  return $exp;
}  

sub confirm_exp {
  my $key = shift;
  return $key if -d $key;
  foreach my $pref (qw/exp.eval. exp.mert. exp.model./) {
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
  my %idx;
  if (-e $indexfile) {
    %idx = map { my ($d, $md5) = split /\t/; ($d, $md5) }
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
