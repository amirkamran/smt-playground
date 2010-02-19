#!/usr/bin/perl
# collects all BLEU.* info

use strict;
use File::Glob ':glob';
use FileHandle;
use IPC::Open2;
use utf8;

binmode STDOUT, ":utf8";

my %collect_info = ();

foreach my $path (bsd_glob("exp.*/BLEU.*")) {
  my ($dir, $fn) = split /\//, $path;
  next if -l $dir; # ignore symlinks
  my $devsize = linecount($dir."/tuning.ref.0");
  my $esize = linecount($dir."/evaluation.in");
  my $dirtag = "$dir<dev$devsize><eval$esize>";

  $dirtag =~ s/^exp\.mert\.//;
  $dirtag =~ s/^exp\.eval\.//;
  $dirtag =~ s/^exp\.2step\.//;
  my $bleu = pickbleu($path);
  my $bleutype = $fn;
  print "$dirtag\t$bleutype\t$bleu\n";

  # remember to check status of this dir later
  $collect_info{$dir} = $dirtag;
}
foreach my $path (bsd_glob("exp.*/evaluation.in")) {
  my ($dir, $fn) = split /\//, $path;
  next if -l $dir; # ignore symlinks
  my $devsize = linecount($dir."/tuning.ref.0");
  my $esize = linecount($dir."/evaluation.in");
  my $dirtag = "$dir<dev$devsize><eval$esize>";

  $dirtag =~ s/^exp\.mert\.//;
  $dirtag =~ s/^exp\.eval\.//;
  $dirtag =~ s/^exp\.2step\.//;
  $collect_info{$dir} = $dirtag;
}

my @collect_info = sort keys %collect_info;
if (0 < scalar @collect_info) {
  # print the tags
  foreach my $dir (@collect_info) {
    my $tag = firstline($dir."/TAG");
    print "$collect_info{$dir}\tTAG\t$tag\n" if defined $tag;
  }

  my $cmd = "./loginfo.sh -";
  my $pid = open2(*Reader, *Writer, $cmd );
  foreach my $dir (@collect_info) {
    print Writer $dir."\n";
  }
  close Writer;
  while (<Reader>) {
    chomp;
    my $info = $_;
    my $dir = shift @collect_info;
    print "$collect_info{$dir}\tinfo\t$info\n";
  }
  close Reader;
}

sub linecount {
  my $fn = shift;
  open INF, $fn or return undef;
  my $nr = 0;
  while (<INF>) {
    $nr++;
  }
  close INF;
  return $nr;
}

sub firstline {
  my $fn = shift;
  open INF, $fn or return undef;
  my $line = <INF>;
  chomp $line;
  close INF;
  return $line;
}

sub pickbleu {
  my $fn = shift;
  open INF, $fn or return undef;
  binmode INF, ":utf8";
  my $bleu = <INF>;
  close INF;
  return undef if !defined $bleu;
  return $1 if $bleu =~ /BLEU\s*=\s*(.*) at 90\.0.*/;
  return $1 if $bleu =~ /BLEU\s*=\s*(.*) \[/;
  return $1 if $bleu =~ /BLEU\s*=\s*([±0-9.]*),/;
  return $bleu;
}
