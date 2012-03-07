#!/usr/bin/env perl
# Prepares a lattice for system combination based on source words
#   source corpus (used to check token counts and project alignments)
#   hyp+ali, hyp+ali, hyp+ali ...
#     primary system hypotheses, each line with 2 cols: hyp, ali-to-source
# Later, --secondary=hyp+ali will be also supported.
# Unlike the traditional bilang with exactly word-to-word confusion networks
# we allow many words at each point, e.g. Nobel_prize|Nobel_peace_prize
# Our approach ensures that the skeleton is segmented equally with all
# secondaries.

use strict;
use Carp;
use Clone qw(clone);

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

use Getopt::Long;

my $verbose = 0;
my $force_similar_alignment = 0;
  # if two linked words are followed by two identical words
my $cautious = 0;  # require also the linked words to be identical

GetOptions(
  "verbose" => \$verbose,
  "cautious" => \$cautious,
  "force-similar-alignment" => \$force_similar_alignment,
) or exit 1;

my $srcf = shift;
die "usage: $0 src hyp+ali1 hyp+ali2"
  if !defined $srcf;
my @hypfiles = @ARGV;
die "Need at least 2 systems (and the method will work for 3+)"
  if 2 > scalar @hypfiles;

my @hyps = @hypfiles;
@hyps = map { load_hyp_ali($_) } @hyps;

my @srcs;
my $h = my_open($srcf);
while (<$h>) {
  chomp;
  my @ws = split / /, trim($_);
  push @srcs, [ @ws ];
}
close $h;

my $lines = scalar(@srcs);

for(my $sys=0; $sys<scalar(@hyps); $sys++) {
  my $syslines = scalar(@{$hyps[$sys]});
  die "$sys:Bad system $hypfiles[$sys]: expected $lines, got $syslines lines."
    if $syslines != $lines;
}

for(my $i=0; $i<$lines; $i++) {
  for(my $prim=0; $prim<scalar(@hyps); $prim++) {
    my $p = $hyps[$prim]->[$i];
    my $segments = segment_primary_consistently_with_src($p, $srcs[$i]);
    for(my $sec=0; $sec<scalar(@hyps); $sec++) {
      next if $sec == $prim;
      my $s = $hyps[$sec]->[$i];

      my $use_s = $s;
      $use_s = force_similar_alignment($p, $s) if $force_similar_alignment;

      print_bilang($p, $use_s, $srcs[$i], $segments);
    }
  }
}

sub force_similar_alignment {
  my $prim = shift;
  my $sec = shift;

  my @primwords = @{$prim->{'w'}};
  my @secwords = @{$sec->{'w'}};

  # modify alignments of sec to match the alignments of prim
  # if words match with prim
  my $out = clone($sec);
  my %needpairs = ();
  # first collect all pairs of prim-sec words via src alignments
  for (my $p=0; $p < @primwords; $p++) {
    foreach my $src (keys %{$prim->{'hyp2src'}}) {
      foreach my $s (keys %{$sec->{'src2hyp'}}) {
        next if $cautious && $primwords[$p] ne $secwords[$s];
        my $p2 = $p+1;
        my $s2 = $s+1;
        $needpairs{"$p-$s"} = 1
          if defined $primwords[$p2] && defined $secwords[$s2]
            && $primwords[$p2] eq $secwords[$s2]
            || !defined $primwords[$p2] && ! defined $secwords[$s2];
        print "$primwords[$p] should match $secwords[$s]\n"
          if $needpairs{"$p-$s"} && $verbose;
      }
    }
  }
  my @q = keys %needpairs;
  my $dirty = 0;
  my %seen = ();
  while (scalar(@q) > 0) {
    my $pair = shift @q;
    next if $seen{$pair};
    $seen{$pair} = 1;
    my ($p, $s) = split /-/, $pair;
    # clean hyp -to- src only:
    $out->{'hyp2src'}->{$s} = clone($prim->{'hyp2src'}->{$p});
    print "NEW src words linked to $s $secwords[$s]: "
      .join(" ", keys %{$out->{'hyp2src'}->{$s}})."\n"
      if $verbose;
    $dirty = 1;
    # should push any new pairs onto the queue
    # XXX
  }
  if ($dirty) {
    # need to fix src2hyp as well
    my $newsrc2hyp = undef;
    foreach my $s (keys %{$out->{'hyp2src'}}) {
      foreach my $src (keys %{$out->{'hyp2src'}->{$s}}) {
        $newsrc2hyp->{$src}->{$s} = 1;
        print "NEW: $s $secwords[$s] links to srcword $src\n" if $verbose;
      }
    }
    $out->{'src2hyp'} = $newsrc2hyp;

    if ($verbose) {
      foreach my $s (keys %{$sec->{'hyp2src'}}) {
        foreach my $src (keys %{$sec->{'hyp2src'}->{$s}}) {
          print "OLD: $s $secwords[$s] links to srcword $src\n";
        }
      }
    }

  }
  return $out;
}

sub segment_primary_consistently_with_src {
  my $prim = shift;
  my $src = shift;

  my @primwords = @{$prim->{'w'}};
  
  print STDERR "SRC:  @$src\n" if $verbose;
  print STDERR "PRIM: @primwords\n" if $verbose;

  my $outsegments = undef;

  my $p = 0;
  my $start = $p;
  while ($p < scalar(@primwords)) {
    # making span from $p to $end
    my $end = $p;
    my %srccovered = ();

    my $stop = 0;
    do {
      foreach my $s (keys %{$prim->{'hyp2src'}->{$p}}) {
        $srccovered{$s} = 1;
        foreach my $p2 (keys %{$prim->{'src2hyp'}->{$s}}) {
          $end = $p2 if $end < $p2; # extend the length of our span
        }
      }
      # the end might have grown (jumped) higher than p
      # increase p by one if this indeed happened
      if ($p < $end) {
        $p++;
        $stop = 0;
      } else {
        $stop = 1;
      }
    } while (! $stop);
    # print "SPAN: @primwords[$start..$end]\t";
    # print "  covers: ".join(" ", map { $src->[$_] } sort keys %srccovered)."\n";

    my $prim_seg_words = join("_", @primwords[$start..$end]);
    push @$outsegments, { "start" => $start, "end" => $end,
                          "srccovered" => [ keys %srccovered ],
                          "prim_seg_words" => $prim_seg_words,
                        };

    $p++;
    $start = $p;
  }
  return $outsegments;
}

sub print_bilang {
  my $prim = shift;
  my $sec = shift;
  my $src = shift;
  my $segments = shift;

  my @primwords = @{$prim->{'w'}};
  my @secwords = @{$sec->{'w'}};

  my %seccovered = ();
  # mark all secondary words that are covered by (the covered) source words
  # avoid covering the same secondary word in more than one (the first) segment
  foreach my $seg (@$segments) {
    my $srccovered = $seg->{"srccovered"};
    next if ! defined $srccovered;
    my %seccovered_by_this_span = ();
    foreach my $srcw (@$srccovered) {
      foreach my $secw (keys %{$sec->{'src2hyp'}->{$srcw}}) {
        $seccovered_by_this_span{$secw} = 1 if !$seccovered{$secw};
        $seccovered{$secw} = 1;
      }
    }
    $seg->{"seccovered"} = [ sort keys %seccovered_by_this_span ];
  }
  # attach all sec. words to closest following attached one
  my $attach_to = undef;
  my @emit_at = (); # one extra elem for tail words
  for(my $secw = $#secwords; $secw >= 0; $secw--) {
    if ($seccovered{$secw}) {
      $attach_to = $secw;
      $emit_at[$secw] = [$secw];
    } else {
      if (defined $attach_to) {
        unshift @{$emit_at[$attach_to]}, $secw; # prepend the word there
      } else {
        unshift @{$emit_at[$#secwords+1]}, $secw;
      }
    }
  }

  # walk the spans again, adding secondary words to segments
  # optionally printing: primary   secondary   source
  my @out = ();
  foreach my $seg (@$segments) {
    my $srccovered = $seg->{"srccovered"};
    my $seccovered = $seg->{"seccovered"};
    my @selected_secwords = (); # will include also the attached ones
    if (defined $seccovered) {
      foreach my $secw (@$seccovered) {
        push @selected_secwords, @{$emit_at[$secw]}
          if defined $emit_at[$secw];
      }
    }

    my @sec_seg_words = map { $secwords[$_] } sort {$a<=>$b} @selected_secwords;
    my $sec_seg_words_string = '$';
    $sec_seg_words_string = join("_", @sec_seg_words)
      if 0 < scalar @sec_seg_words;
    push @out, $sec_seg_words_string."|".$seg->{"prim_seg_words"};

    # print the words if verbose
    my $start = $seg->{"start"};
    my $end = $seg->{"end"};
    if ($verbose) {
      print STDERR "@primwords[$start..$end]";
      print STDERR "\t";
      print STDERR "@sec_seg_words";
      print STDERR "\t";
      print STDERR join(" ", map { $src->[$_] } @$srccovered)
        if defined $srccovered;
      print STDERR "\n";
    }
  }
  if (defined $emit_at[$#secwords+1]) {
    my @sec_seg_words = map { $secwords[$_] } @{$emit_at[$#secwords+1]};
    push @out, join("_", @sec_seg_words).'|$';
    print STDERR "\t@sec_seg_words\t\n" if $verbose;
  }
  print STDERR "\n" if $verbose;

  print "@out\n";
}


sub load_hyp_ali {
  my $fname = shift;
  my $h = my_open($fname);
  my @sents = ();
  my $nr = 0;
  while (<$h>) {
    $nr++;
    chomp;
    my ($hyp, $ali) = split /\t/, trim($_);
    die "$fname:$nr:Found '|', forbidden!" if $hyp =~ /\|/;
    $hyp =~ s/\$/&dollar;/g;
    $hyp =~ s/_/&underscore;/g;
    my @ws = split / /, $hyp;
    my $out = undef;
    $out->{'w'} = [ @ws ];
    my @ali = map { my ($a,$b) = split /-/, $_; [$a, $b] } split / /, $ali;
    foreach my $pair (split / /, $ali) {
      my ($a,$b) = split /-/, $pair;
      $out->{'src2hyp'}->{$a}->{$b} = 1;
      $out->{'hyp2src'}->{$b}->{$a} = 1;
    }
    push @sents, $out;
  }
  close $h;
  return \@sents;
}

sub trim {
  my $s = shift;
  $s =~ s/ +\t/\t/g;
  $s =~ s/\t +/\t/g;
  $s =~ s/  +/ /g;
  $s =~ s/^ +//g;
  $s =~ s/ +$//g;
  return $s;
}

sub my_open {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDIN, ":utf8");
    return *STDIN;
  }

  confess "Not found: $f" if ! -e $f;

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
