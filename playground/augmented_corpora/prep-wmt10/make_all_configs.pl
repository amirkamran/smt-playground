#!/usr/bin/perl

use strict;

while (<>) {
  next if /^\s*#/ || /^\s*$/;
  chomp;
  my $line = $_;
  s/ *\t */\t/g;
  s/^ *| *$//g;
  my ($outcorpname, $langs, $scentype, $sectionre, $domainre, $comment)
    = split /\t/;
  foreach my $langnames (split /,/, $langs) {
    my ($lang, $outlangname) = split /:/, $langnames;
    $outlangname = $lang if ! defined $outlangname;
    if (-e "../$outcorpname/$outlangname.gz" ) {
      print STDERR "Skipped existing ../$outcorpname/$outlangname.gz\n";
      next;
    }
    $ENV{"OUTCORPNAME"} = $outcorpname;
    $ENV{"ANOTLANG"} = $lang;
    $ENV{"OUTLANG"} = $outlangname;
    $ENV{"SCENTYPE"} = $scentype;
    $ENV{"SECTIONRE"} = $sectionre;
    $ENV{"DOMAINRE"} = $domainre;
    foreach my $varname(qw(OUTCORPNAME ANOTLANG OUTLANG SCENTYPE SECTIONRE DOMAINRE)) {
      print STDERR "$varname: $ENV{$varname}\n";
    }
    safesystem("make analyze") or die "Failed at: $line\n";
  }
}


sub safesystem {
  # print STDERR "Executing: @_\n";
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
