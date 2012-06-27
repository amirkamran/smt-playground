#!/usr/bin/perl
# Give a list of files(!) as arguments and I will make all files equal to the first one be a direct hardlink to it
#
# This is a way to get candidates of files.
# du -x -S -b -l -a | coltest ' -f $2' | grp --keys=1 --items=2,COLLECT2 | coltest '$2>1' | numsort n1 | coltest '$1>1000000' | cut -f3- | prefix 'hardlink_equal_files ' | sed 's/, / /g'

use strict;
use warnings;
use Getopt::Long;

my $force = 0;
my $prepare = 0;
my $minsize = 100000;
GetOptions(
  "force" => \$force,
  "prepare" => \$prepare,
  "minsize=i" => \$minsize, # for preparation
) or exit 1;

if ($prepare) {
  # just dump a script that will run me
  my $suffixforce = $force ? " | suffix ' --force'" : "";
  system("du -x -S -b -l -a | coltest ' -f \$2' | grp --keys=1 --items=2,COLLECT2 | coltest '\$2>1' | numsort n1 | coltest '\$1>$minsize' | cut -f3- | prefix 'hardlink_equal_files ' | sed 's/, / /g' ".$suffixforce);
  exit 0;
}

my $etalon = shift;
die "usage" if ! -f $etalon;

sub inodenum {
  my $filename = shift;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($filename);
  return $ino;
}

my $etaloninode = inodenum($etalon);

foreach my $f (@@ARGV) {
  if ( ! -f $f) {
    print STDERR "$f is not a file\n";
    next;
  }
  if (inodenum($f) == $etaloninode) {
    print STDERR "Already hardlinked: $f\n";
    next;
  }
  my $same = safesystem("diff -q $f $etalon");
  if (! $same) {
    print STDERR "File seems different to etalon: $f\n";
    next;
  }
  print STDERR "File is same! Will hardlink: $f\n";
  if ($force) {
    unlink($f) or die "Failed to unlink $f";
    safesystem("ln $etalon $f") or die "Failed to run: 'ln $etalon $f'";
  }
}

print STDERR "No changes made yet, use --force.\n" if !$force;

sub safesystem {
  print STDERR "Executing: @@_\n";
  system(@@_);
  if ($? == -1) {
      print STDERR "Failed to execute: @@_\n  $!\n";
      exit(1);
  }
  elsif ($? & 127) {
      printf STDERR "Execution of: @@_\n  died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
      exit(1);
  }
  else {
    my $exitcode = $? >> 8;
    print STDERR "Exit code: $exitcode\n" if $exitcode;
    return ! $exitcode;
  }
}

