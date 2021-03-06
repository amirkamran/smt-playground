#!/usr/bin/perl
# Runs GIZA++ (in parallel, if wished) on specified bitext.
# Ondrej Bojar, obo@cuni.cz
# partially based on train-factored-phrase-model.perl from Moses
#
# Runs either on two files or on one file (column 1 and 2).
# The output is several columns, one for each request symmetrization
# (--dirsym=X) and two more columns for alignment quality as reported by GIZA:
# first for the 'there' direction (ie. "a-b"), then for the 'back' direction
# (ie. "b-a").
#
#   there = (from) left   = a-b  =    f(src)=tgt
#   back  = (from) right  = b-a  =    f(tgt)=src
#
# Note that gdf* symmetrizations cannot be simply reversed.

use strict;
use utf8;
use warnings;
use Carp;
use Getopt::Long;
use File::Temp qw /tempdir/;
use threads;
use File::Path;
use File::Basename;
use File::Copy;
use Cwd 'abs_path';

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $tempdir = "/tmp";
my $parallel = 1; # run the two GIZA runs simultaneously
my @dirsyms = ();
      # right, left   ... for unidirectional GIZA only
      # gdf, intersect, union   ... for two runs, symmetrized
# my $splits = 0;
# my $split = undef;
my $bindir = "/no/bindir/specified";
my $mgizadir = undef;
my $mgizacores = undef;
my $mgizamodel = undef;
my $lfactors = undef;
my $rfactors = undef;
my $lcol = 0;
my $rcol = 1;
my $giza_extra_options = "";
my $drop_bad_lines = 0;
my $continue_dir = undef; # continue working on a directory, if killed
                          # some steps are re-done anyway, but eg. giza is
                          # skipped, if output appears to be ready
my $keep = 0;  # keep tempdir even on successful finish

print STDERR "ARGS: @ARGV\n";

GetOptions(
  "parallel!" => \$parallel,
 # "compress!" => \$compress,
  "bindir=s" => \$bindir,
  "mgizadir=s" => \$mgizadir,
  "mgizacores=i" => \$mgizacores,
  "mgizamodel=s" => \$mgizamodel,
  "tempdir=s" => \$tempdir,
  "continue-dir=s" => \$continue_dir, # continue working in this directory
  # Splits are not supported yet.
  # "splits=i" => \$splits, # assume the corpus has i sections
  # "split=i" => \$split, # and we should run only the (i-1)th of them
  "dirsym=s@" => \@dirsyms, # direction or symmetrization method
  "lfactors=s" => \$lfactors, # use only some of the left factors
  "rfactors=s" => \$rfactors, # use only some of the right factors
  "lcol=i" => \$lcol, # use a different column of a bicolumn input, not 0
  "rcol=i" => \$rcol, # use a different column of a bicolumn input, not 1
  "drop-bad-lines" => \$drop_bad_lines, # try to ignore some minor problems
  "keep" => \$keep,
  "giza-flags=s" => \$giza_extra_options,
) or exit 1;

my ( $MKCLS, $GIZA, $SNT2COOC, $SYMAL, $MERGE );

if (defined $mgizadir) {
  $MKCLS = "$mgizadir/mkcls";
  $GIZA = "$mgizadir/mgiza";
  $SNT2COOC = "$mgizadir/snt2cooc";
  $SYMAL = "$mgizadir/symal";
  $MERGE = "$mgizadir/merge_alignment.py";
} else {
  $MKCLS = "$bindir/mkcls";
  $GIZA = "$bindir/GIZA++";
  $SNT2COOC = "$bindir/snt2cooc.out";
  $SYMAL = "$bindir/symal";
}

if (defined $mgizadir && ! defined $mgizacores) {
  chomp($mgizacores = `cat /proc/cpuinfo | grep -E '(CPU|processor)' | wc -l`);
  print STDERR "Guessed $mgizacores CPU cores.\n";
  $mgizacores /= 2 if $parallel;
}

map { confess "Can't run $_" if ! -x $_ } ( $MKCLS, $GIZA, $SNT2COOC, $SYMAL );

my $filea = shift;
my $fileb = shift;

if (!defined $filea) {
  print STDERR "usage: $0 fileA fileB  > alignment
     or: $0 fileAB  > alignment
For options see the source code.
";
  exit 1;
}

# validate and interpret factors
($lfactors, $rfactors) = map {
  if (defined $_) {
    confess "Bad factors spec: $_" if !/^[0-9]+(,[0-9]+)*$/;
    my @use_indexes = split /,/, $_;
    [ @use_indexes ];
  } else {
    undef;
  }
} ($lfactors, $rfactors);

# normalize dirsyms
my @normdirsyms = ();
foreach my $d (@dirsyms) {
  push @normdirsyms, split(/[, ]+/, $d);
}
@dirsyms = @normdirsyms;
@dirsyms = ("grow-diag-final", "left", "right") if 0 == scalar @dirsyms;

# check which symmetrizations do we need, validate symmetrization requests
my %simple_needed = ();
my %symmetrized_needed = ();
foreach my $req (@dirsyms) {
  if ($req eq "left" || $req eq "right" ) {
    $simple_needed{$req} = 1;
  } else {
    my $symalargs = make_symal_args($req);
    confess "Bad symmetrization type: '$req'" if ! defined $symalargs;
    $symmetrized_needed{$req} = $symalargs;
    # any symmetrization needs both left and right alignments
    $simple_needed{"left"} = 1;
    $simple_needed{"right"} = 1;
  }
}


confess "Nothing to do. Use at least one --dirsym."
  if 0 == scalar keys %simple_needed && 0 == scalar keys %symmetrized_needed;


my $tmp;

if (defined $continue_dir) {
  print STDERR "Continuing in directory: $continue_dir\n";
  $tmp = $continue_dir;
} else {
  $tmp = tempdir("gizawrapXXXX", CLEANUP=>0, DIR=>$tempdir);
}

print STDERR "My tempdir: $tmp\n";

my $insents;
my $sentnums;
if (!defined $fileb) {
  # assuming filea has two columns
  my $r = restrict_factors_and_section_from_twocolfile(
            $filea, "$tmp/txt-a", "$tmp/txt-b",
            $lcol, $rcol, $lfactors, $rfactors);
  ($insents, $sentnums) = @$r;
} else {
  my ($ra, $rb) = may_parallel(
      sub { restrict_factors_and_section($filea, "$tmp/txt-a", $lfactors) },
      sub { restrict_factors_and_section($fileb, "$tmp/txt-b", $rfactors) }
  );
  my ($insentsa, $sentnumsa) = @$ra;
  my ($insentsb, $sentnumsb) = @$rb;
  confess "Incompatible sent counts: $insentsa vs. $insentsb"
    if $insentsa != $insentsb;
  $insents = $insentsa;
  $sentnums = $sentnumsa;
}
confess "No sentences!" if $insents == 0;

print STDERR "Running GIZA on $insents sentences.\n";

my ($vcba, $vcbb);

if (defined $mgizamodel) {
  if (! defined $mgizadir) {
    die "Only MGIZA++ supports using existing models.";
  }
  $mgizamodel = abs_path($mgizamodel);
  print STDERR "Running MGIZA++ alignment with model: $mgizamodel\n";
  symlink "$mgizamodel/vcb-a.classes", "$tmp/vcb-a.classes";
  symlink "$mgizamodel/vcb-b.classes", "$tmp/vcb-b.classes";
  ($vcba, $vcbb) = may_parallel(
    sub { update_vocab("$tmp/txt-a", "$mgizamodel/vcb-a", "$tmp/vcb-a") },
    sub { update_vocab("$tmp/txt-b", "$mgizamodel/vcb-b", "$tmp/vcb-b") }
  );
} else {
  ## BEWARE Do not rename vcb-*.classes or GIZA won't find it and won't complain
  may_parallel(
    sub { make_classes("$tmp/txt-a", "$tmp/vcb-a.classes") },
    sub { make_classes("$tmp/txt-b", "$tmp/vcb-b.classes") }
  );

  my $vcba_file = "$tmp/vcb-a";
  my $vcbb_file = "$tmp/vcb-b";
  ($vcba, $vcbb) = may_parallel(
    sub { collect_vocabulary("$tmp/txt-a", $vcba_file) },
    sub { collect_vocabulary("$tmp/txt-b", $vcbb_file) }
  );
  print STDERR "Vocabulary sizes: "
  .(scalar keys %$vcba)
  ." and "
  .(scalar keys %$vcbb)
  ."\n";
}

my %vcb = ("a"=>$vcba, "b"=>$vcbb);

my %alifilename = ();
# maps alignment and symmetrization names to filenames

my @simple_needed = keys %simple_needed;
if (1 == scalar @simple_needed) {
  # just one giza run needed
  my $dirsym = shift @simple_needed;
  my ($usea, $useb);
  if ($dirsym eq "left") {
    ($usea, $useb) = ("a", "b");
  } else {
    ($usea, $useb) = ("b", "a");
  }
  my $alifile = run_giza($tmp, $usea, $useb,
        $vcb{$usea}, $vcb{$useb},
        "$tmp/vcb-$usea", "$tmp/vcb-$useb",
        "$tmp/txt-$usea", "$tmp/txt-$useb");

  # process the giza output and emit it (swapped if needed)
  *ALI = my_open($alifile);
  my $cnt = 0;
  while (!eof(ALI)) {
    my ($leftwords, $rightwords, $aliarr, $senta, $sentb, $aliscore)
      = ReadAlign(*ALI);
    $cnt++;
    # print shift(@$sentnums), "\t"; # don't emit sentence number
    # no way to check if got expected number of words left or right
    for(my $i=1; $i<scalar(@$aliarr); $i++) {
      if ($dirsym eq "left") {
        next if !defined $aliarr->[$i] || $aliarr->[$i] == 0; # NULL
        my $a = $i-1;
        my $b = $aliarr->[$i] -1;
        print "$a-$b";
      } else {
        my $a = $i-1;
        my $b = $aliarr->[$i] -1;
        print "$b-$a";
      }
      print " " if $i+1 <= @$aliarr;
    }
    print "\t";
    print $aliscore if defined $aliscore;
    print "\n";
  }
  close ALI;
  print STDERR "My tempdir: $tmp\n";
  print STDERR "Aligned $insents sentences, some may have truncated alignments.\n";
  confess "Lost some sentences" if $insents != $cnt;
} else {
  # run two gizas and possibly also symmetrizations
  my ($aliback, $alithere) = may_parallel(
    sub {
      my ($usea, $useb) = ("a", "b");
      return run_giza($tmp, $usea, $useb,
        $vcb{$usea}, $vcb{$useb},
        "$tmp/vcb-$usea", "$tmp/vcb-$useb",
        "$tmp/txt-$usea", "$tmp/txt-$useb");
    },
    sub {
      my ($usea, $useb) = ("b", "a");
      return run_giza($tmp, $usea, $useb,
        $vcb{$usea}, $vcb{$useb},
        "$tmp/vcb-$usea", "$tmp/vcb-$useb",
        "$tmp/txt-$usea", "$tmp/txt-$useb");
    },
  );

  $alifilename{"left"} = "$tmp/out.left.gz";
  $alifilename{"right"} = "$tmp/out.right.gz";
  $alifilename{"aliscorefile"} = "$tmp/out.there-and-back-scores.gz";
  # for direct and reverse gdfa
  my @symalinfile = ("$tmp/symalinput.gz", "$tmp/symalinput-rev.gz");

  # convert GIZA output to symal input, and save also left and right files
  print STDERR "Preparing for symal.\n";
  *ALITHERE = my_open($alithere);
  *ALIBACK = my_open($aliback);
  *SYMAL = my_save($symalinfile[0]);
  *SYMALREV = my_save($symalinfile[1]);
  *LEFT = my_save($alifilename{"left"});
  *RIGHT = my_save($alifilename{"right"});
  *ALISCORES = my_save($alifilename{"aliscorefile"});
  my $cnt = 0;
  my @skip_at = ();
  while (!eof(ALITHERE)) {
    my ($ok, $alitherearr, $alibackarr, $senta, $sentb, $sent_weight,
        $aliscorethere, $aliscoreback)
      = ReadBiAlign(undef,*ALITHERE,*ALIBACK);
    $cnt++;
    if ($ok) {
      my @a = @$alitherearr;
      my @b = @$alibackarr;
      print SYMAL "$sent_weight\n";
      print SYMAL $#a," $senta \# @a[1..$#a]\n";
      print SYMAL $#b," $sentb \# @b[1..$#b]\n";
      print SYMALREV "$sent_weight\n";
      print SYMALREV $#b," $sentb \# @b[1..$#b]\n";
      print SYMALREV $#a," $senta \# @a[1..$#a]\n";
      for (my $i=0; $i<$#b; $i++) {
        print LEFT $i, "-", $b[$i+1]-1, " " if $b[$i+1] > 0;
      }
      print LEFT "\n";
      for (my $i=0; $i<$#a; $i++) {
        print RIGHT $a[$i+1]-1, "-", $i, " " if $a[$i+1] > 0;
      }
      print RIGHT "\n";
      print ALISCORES $aliscoreback, "\t", $aliscorethere, "\n";
      # back =~ left, there =~ right
    } else {
      # print STDERR "Skipping sent $cnt\n";
      push @skip_at, $cnt;
      print LEFT "\n";
      print RIGHT "\n";
      print ALISCORES "\n";
    }
  }
  close ALITHERE;
  close ALIBACK;
  close SYMAL;
  close SYMALREV;
  close LEFT;
  close RIGHT;
  close ALISCORES;

  # run all symmetrizations and emit to our temp files including skipped lines
  my $skipped = undef;
  foreach my $dirsym (keys %symmetrized_needed) {
    my $symaloutfn = "$tmp/out.$dirsym.gz";
    $alifilename{$dirsym} = $symaloutfn;
    my ($revsymal, $symalargs) = @{$symmetrized_needed{$dirsym}};

    if (-e $symaloutfn) {
      print STDERR "Reusing exising $symaloutfn\n";
    } else {
      *SYMALOUT = my_save($symaloutfn);
      open SYMAL, "zcat $symalinfile[$revsymal] | $SYMAL $symalargs |"
        or confess "Failed to run symal ($symalargs)";
      $cnt = 0;
      my @this_skip_at = @skip_at;
      $skipped = 0;
      while(<SYMAL>) {
        $cnt++;
        while (defined $this_skip_at[0] && $this_skip_at[0] == $cnt) {
          print STDERR "Printing blank line for skipped sent $cnt\n";
          $skipped++;
          $cnt++;
          shift @this_skip_at;
          print SYMALOUT "\n"; # add extra line for the skipped sentence
        }
        shift(@$sentnums);
        if ($revsymal) {
          # need to reverse symal's output
          s/([0-9]+)-([0-9]+)/$2-$1/g;
        }
        s/.*{##} // if defined $mgizadir; # mgiza also outputs the sentences
        print SYMALOUT $_; # print the original line
      }
      $cnt++; # skip_at counts at +1
      while (defined $this_skip_at[0] && $this_skip_at[0] == $cnt) {
        # print STDERR "Printing blank line for skipped sent $cnt\n";
        $skipped++;
        $cnt++;
        shift @this_skip_at;
        print "\n"; # add extra line for the skipped sentence
      }
      $cnt--; # skip_at counts at +1
      close SYMAL;
      close SYMALOUT;

      confess "Didn't produce correct number of sentences! Expected $insents, got $cnt. Remaining skip_at: @this_skip_at."
        if $insents != $cnt;
    }
  }

  # merge all alignments into output
  # append also the alignment scores stored in $alifilename{aliscorefile}
  my @temphdls = map {
                       my $fn = $alifilename{$_};
                       print STDERR "Will emit $fn\n";
                       my $fh = my_open($fn);
                       $fh;
                     } (@dirsyms, "aliscorefile");
  my $nr = 0;
  while (!eof($temphdls[0])) {
    $nr++;
    for(my $i=0; $i<=$#temphdls; $i++) {
      my $line = readline($temphdls[$i]);
      if (! defined $line) {
        confess "$alifilename{$dirsyms[$i]}:$nr: File too short!" if $i != 0;
      } else {
        chomp $line;

        print $line;
        if ($i == $#temphdls) {
          print "\n";
        } else {
          print "\t";
        }
      }
    }
  }
  # close all files
  map { close $_ } @temphdls;

  print STDERR "My tempdir: $tmp\n";
  print STDERR "Aligned and symmetrized $insents sentences, skipped $skipped"
    ." blank lines.\n";
}



if ($keep) {
  print STDERR "Keeping $tmp, delete yourself.\n";
} else {
  rmtree($tmp);
}


sub ReadAlign{
  # based on giza2bal.pl by Marcello Federico; from Moses scripts
  my $fd = shift;
  my($t1,$s1);
  my @a = ();

  my $stats=<$fd>; ## header
  chomp($s1=<$fd>);
  chomp($t1=<$fd>);

  my $aliscore = undef;
  chomp $stats;
  $aliscore = $1 if $stats =~ / : (.+)$/;

  #get target statistics
  my $n=1;
  $t1=~s/NULL \(\{(( \d+)*) \}\)//;
  while ($t1=~s/(\S+) \(\{(( \d+)*) \}\)//){
      foreach $_ (split / /, $2) {
        next if $_ eq "";
        $a[$_] = $n;
      }
      $n++;
  }

  my @s1 = split / /, $s1;
  my $M=scalar @s1;

  for (my $j=1;$j<$M+1;$j++){
      $a[$j]=0 if !$a[$j];
  }

  return ($n-1, $M,\@a, $s1, $t1, $aliscore);
}


sub ReadBiAlign{
  # based on giza2bal.pl by Marcello Federico; from Moses scripts
  my($fd0,$fd1,$fd2)=@_;
  my($dummy);
  my($t1,$t2, $s1, $s2, $stats);
  my(@a, @b, $c);

  if (defined $fd0) {
    chomp($c=<$fd0>); ## count
    $dummy=<$fd0>; ## header
    $dummy=<$fd0>; ## header
  }
  $c=1 if !$c;

  chomp($stats=<$fd1>); ## header
  chomp($s1=<$fd1>);
  chomp($t1=<$fd1>);
  my $aliscore1 = $1 if $stats =~ / : (.+)$/;

  chomp($stats=<$fd2>); ## header
  chomp($s2=<$fd2>);
  chomp($t2=<$fd2>);
  my $aliscore2 = $1 if $stats =~ / : (.+)$/;

  @a=@b=();

  #get target statistics
  my $n=1;
  $t1=~s/NULL \(\{(( \d+)*) \}\)//;
  while ($t1=~s/(\S+) \(\{(( \d+)*) \}\)//){
      # grep($a[$_]=$n,split(/ /,$2));
      foreach $_ (split / /, $2) {
        next if $_ eq "";
        $a[$_] = $n;
      }
      $n++;
  }

  my $m=1;
  $t2=~s/NULL \(\{(( \d+)*) \}\)//;
  while ($t2=~s/(\S+) \(\{(( \d+)*) \}\)//){
      # grep($b[$_]=$m,split(/ /,$2));
      foreach $_ (split / /, $2) {
        next if $_ eq "";
        $b[$_] = $m;
      }
      $m++;
  }

  my @s1 = split / /, $s1;
  my $M=scalar @s1;
  my @s2 = split / /, $s2;
  my $N=scalar @s2;

  return (0, undef, undef, $s1, $s2, $c, $aliscore1, $aliscore2)
    if $m != ($M+1) || $n != ($N+1);

  for (my $j=1;$j<$m;$j++){
      $a[$j]=0 if !$a[$j];
  }

  for (my $i=1;$i<$n;$i++){
      $b[$i]=0 if !$b[$i];
  }

  return (1, \@a, \@b, $s1, $s2, $c, $aliscore1, $aliscore2);
}


#### Subroutines


sub restrict_factors_and_section {
  my $infile = shift;
  my $outfile = shift;
  my $factors = shift;

  if (-e $outfile) {
    *INF = my_open($outfile);
    my $sents = 0;
    $sents++ while (<INF>);
    close INF;
    print STDERR "Reusing $outfile, assuming that no sentence was skipped.\n";
    my @sentnums = (1..$sents);
    return [$sents, [@sentnums]];
  }

  my $seen_factors = undef;
  *INF = my_open($infile);
  open OUTF, ">$outfile" or confess "Can't write $outfile";
  binmode(OUTF, ":utf8");
  my $nl = 0;
  my $sents = 0;
  while(<INF>) {
    $nl++;
    # if ($splits) { # skip sentences not belonging to our split
    # }
    chomp;
    ($seen_factors, $_)
      = trim_and_restrict_to_factors($factors, $seen_factors, $_, $infile, $nl);
    confess "$infile:$nl:Empty line" if $_ eq "";
    print OUTF $_."\n";
    $sents++;
    # Verbose output so that the user can quickly check
    if ($sents < 3) {
      print STDERR "Preview, s$sents: $_\n";
    }
  }
  close INF;
  close OUTF;
  my @sentnums = (1..$sents);
    # we do not allow skipping any sentences => return all numbers
  print STDERR "Read $nl lines, got $sents sentences\n";
  return [$sents, [@sentnums]];
}

sub restrict_factors_and_section_from_twocolfile {
  my $infile = shift;
  my $outfilea = shift;
  my $outfileb = shift;
  my $cola = shift;
  my $colb = shift;
  my $factorsa = shift;
  my $factorsb = shift;
  my @sentnums = ();

  if (-e $outfilea && -e $outfileb) {
    *INF = my_open($outfilea);
    my $sents = 0;
    $sents++ while (<INF>);
    close INF;
    print STDERR "Reusing $outfilea and $outfileb, assuming that no sentence was skipped.\n";
    my @sentnums = (1..$sents);
    return [$sents, [@sentnums]];
  }
  my $seen_factorsa = undef;
  my $seen_factorsb = undef;
  *INF = my_open($infile);
  open OUTFA, ">$outfilea" or confess "Can't write $outfilea";
  open OUTFB, ">$outfileb" or confess "Can't write $outfileb";
  binmode(INF, ":utf8");
  binmode(OUTFA, ":utf8");
  binmode(OUTFB, ":utf8");
  my $nl = 0;
  my $sents = 0;
  while(<INF>) {
    $nl++;
    # if ($splits) { # skip sentences not belonging to our split
    # }
    chomp;
    my @line = split /\t/;
    my $senta = $line[$cola];
    my $sentb = $line[$colb];
    ($seen_factorsa, $senta)
      = trim_and_restrict_to_factors($factorsa, $seen_factorsa, $senta,
          $infile, $nl);
    ($seen_factorsb, $sentb)
      = trim_and_restrict_to_factors($factorsb, $seen_factorsb, $sentb,
          $infile, $nl);
    if ($senta eq "" || $sentb eq "") {
      print STDERR "$infile:$nl:Empty line in col 1\n" if $senta eq "";
      print STDERR "$infile:$nl:Empty line in col 2\n" if $sentb eq "";
      confess if !$drop_bad_lines;
      next;
    }
    # Main output files
    print OUTFA $senta."\n";
    print OUTFB $sentb."\n";
    push @sentnums, $nl;
    $sents++;
    # Verbose output so that the user can quickly check
    if ($sents < 3) {
      print STDERR "Preview A, s$sents: $senta\n";
      print STDERR "Preview B, s$sents: $sentb\n";
    }
  }
  close INF;
  close OUTFA;
  close OUTFB;
  print STDERR "Read $nl lines, got $sents sentences\n";
  return [$sents, [@sentnums]];
}

sub trim_and_restrict_to_factors {
  my $factors = shift;
  my $seen_factors = shift;
  my $sent = shift;
  my $fn = shift; # for error reporting
  my $nl = shift; # for error reporting

  $sent =~ s/\s+/ /g;
  $sent =~ s/^\s|\s$//g;

  if (defined $factors) {
    my @words = split / /, $sent;;
    my @outwords = ();
    foreach my $w (@words) {
      my @facts = split /\|/, $w;
      my $got_factors = scalar(@facts);
      confess "$fn:$nl:Bad number of factors, expecting $seen_factors, got $got_factors in:"
        ."\n$sent\n"
        if defined $seen_factors && $seen_factors != $got_factors;
      $seen_factors = $got_factors;
      my @outfacts = map {
        confess "$fn:$nl:Missed factor $_ in $w in:\n$sent\n"
          if !defined $facts[$_];
        $facts[$_];
      } @$factors;
      push @outwords, join("|", @outfacts);
    }
    $sent = join(" ", @outwords);
  }
  return ($seen_factors, $sent);
}

sub collect_vocabulary {
  my $src = shift;
  my $tgt = shift;

  print STDERR "Collecting vocabulary for $src\n";

  my %count;
  open(TXT,$src) or confess "Can't read $src";
  binmode(TXT, ":utf8");
  while(<TXT>) {
      chomp;
      foreach (split) { $count{$_}++; }
  }
  close(TXT);

  my %VCB;
  open(VCB,">$tgt") or confess "Can't write $tgt";
  binmode(VCB, ":utf8");
  print VCB "1\tUNK\t0\n";
  my $id=2;
  foreach my $word (sort {$count{$b}<=>$count{$a}} keys %count) {
    my $count = $count{$word};
    printf VCB "%d\t%s\t%d\n",$id,$word,$count;
    $VCB{$word} = $id;
    $id++;
  }
  close(VCB);

  return \%VCB;
}

sub numberize_and_merge {
  my ($VCB_A,$in_a,$VCB_B,$in_b,$out) = @_;
  my %OUT;
  # print STDERR "(1.3) numberizing corpus $out @ ".`date`;
  if (-e $out) {
      print STDERR "  $out already in place, reusing\n";
      return;
  }
  open(IN_A,$in_a) or confess "Can't read $in_a";
  open(IN_B,$in_b) or confess "Can't read $in_b";
  open(OUT,">$out") or confess "Can't write $out";
  binmode(IN_A, ":utf8");
  binmode(IN_B, ":utf8");
  binmode(OUT, ":utf8");
  while(my $a = <IN_A>) {
      my $b = <IN_B>;
      print OUT "1\n";
      print OUT numberize_line($VCB_B,$b);
      print OUT numberize_line($VCB_A,$a);
  }
  close(IN_A);
  close(IN_B);
  close(OUT);
}

sub numberize_line {
  my ($VCB,$txt) = @_;
  chomp($txt);
  my $out = "";
  my $not_first = 0;
  foreach (split(/ /,$txt)) {
      next if $_ eq '';
      $out .= " " if $not_first++;
      confess "Unknown word '$_'\n" unless defined($VCB->{$_});
      $out .= $VCB->{$_};
  }
  return $out."\n";
}

sub make_classes {
  my $src = shift;
  my $tgt = shift;
  confess "Can't find $src" if ! -e $src;
  if (-e $tgt) {
    print STDERR "Reusing existing $tgt\n";
    return;
  }

  my $cmd = "$MKCLS -c50 -n2 -p$src -V$tgt opt >&2";
  safesystem($cmd); # ignoring the wrong exit code from mkcls (not dying)
}


sub run_giza {
  my($dir,$a,$b,$vcba, $vcbb, $vcba_file, $vcbb_file,
    $infile_a,$infile_b) = @_;

  confess "Missing vcba file: $vcba_file" if ! -e $vcba_file;
  confess "Missing vcbb file: $vcbb_file" if ! -e $vcbb_file;
  confess "Missing classes for vcba file: $vcba_file.classes"
    if ! -e $vcba_file.".classes";
  confess "Missing classes for vcbb file: $vcbb_file.classes"
    if ! -e $vcbb_file.".classes";

  my $outprefix = "$dir/$a-$b";
  my $outfile = "$outprefix.A3.final";
  #$outfile .= '.gz' if $compress && defined $mgizadir;
    # plain GIZA does not gzip its output

  if (-e $outfile) {
    print STDERR "  $outfile seems finished, reusing.\n";
    return $outfile;
  }

  my $traincorpus = "$dir/$a-$b.snt";
  if (-e $traincorpus) {
    print STDERR "  $traincorpus seems finished, reusing.\n";
  } else {
    numberize_and_merge($vcba, $infile_a, $vcbb, $infile_b, $traincorpus);
  }

  my $cooc_file = "$dir/$a-$b.cooc";
  my $snt2cooc_call;

  if (-e $cooc_file || -e "$cooc_file.gz") {
    $cooc_file .= '.gz' if ! -e $cooc_file;
    print STDERR "  $cooc_file seems finished, reusing.\n";
  } else {
    if (defined $mgizadir) {
      $snt2cooc_call = "$SNT2COOC $cooc_file $vcba_file $vcbb_file $traincorpus";
    } else {
      $snt2cooc_call = "$SNT2COOC $vcba_file $vcbb_file $traincorpus > $cooc_file";
    }
    safesystem($snt2cooc_call) or confess;
    #if ($compress) {
    #  safesystem("gzip $cooc_file");
    #  $cooc_file .= '.gz';
    #}
  }

  my %GizaDefaultOptions;
  if (! $mgizamodel) {
    %GizaDefaultOptions =
      (p0 => .999 ,
       m1 => 5 ,
       m2 => 0 ,
       m3 => 3 ,
       m4 => 3 ,
       o => "giza" ,
       nodumps => 0 ,
       onlyaldumps => 0 ,
       nsmooth => 4 ,
       model1dumpfrequency => 1,
       model4smoothfactor => 0.4 ,
       s => $vcbb_file,
       t => $vcba_file,
       c => $traincorpus,
       CoocurrenceFile => $cooc_file,
       o => $outprefix);
  } else {
    %GizaDefaultOptions =
      (previoust => "$mgizamodel/$a-$b.t3.final" ,
       previousa => "$mgizamodel/$a-$b.a3.final" ,
       previousd => "$mgizamodel/$a-$b.d3.final" ,
       previousn => "$mgizamodel/$a-$b.n3.final" ,
       previousd4 => "$mgizamodel/$a-$b.d4.final" ,
       previousd42 => "$mgizamodel/$a-$b.D4.final" ,
       m1 => 0 , 
       m2 => 0 , 
       mh => 0 , 
       m3 => 0 , 
       m4 => 1 , 
       restart => 11 ,
       s => $vcbb_file,
       t => $vcba_file,
       c => $traincorpus,
       CoocurrenceFile => $cooc_file,
       o => $outprefix);
  }

  if ($giza_extra_options) {
      foreach (split(/[ ,]+/,$giza_extra_options)) {
          my ($option,$value) = split(/=/,$_,2);
          $GizaDefaultOptions{$option} = $value;
      }
  }

  #doesn't work with mgiza
  #$GizaDefaultOptions{"use_gzip"} = 1 if $compress and defined $mgizadir;

  if (defined $mgizadir) {
    $GizaDefaultOptions{"ncpu"} = defined $mgizamodel ? 1 : $mgizacores;
  }

  my $GizaOptions;
  foreach my $option (sort keys %GizaDefaultOptions){
      my $value = $GizaDefaultOptions{$option} ;
      $GizaOptions .= " -$option $value" ;
  }
  
  if (defined $mgizamodel) {
    $GizaOptions = "$mgizamodel/$a-$b.gizacfg " . $GizaOptions;
  }

  safesystem("$GIZA $GizaOptions >&2");

  if (defined $mgizadir) {
    my $redirect = "";
    safesystem("$MERGE $dir/$a-$b.A3.final.part* $redirect > $outfile");
    # safesystem("rm $dir/$a-$b.A3.final.part*");
  }

  confess "Giza did not produce the output file $outfile. Is your corpus clean (reasonably-sized sentences)?"
    if ! -e $outfile;
  return $outfile;
  # safesystem("gzip $outprefix.A3.final") or confess;
}




sub may_parallel {
  my $codea = shift;
  my $codeb = shift;
  if ($parallel) {
    my $ta = threads->new($codea);
    my $resb = &$codeb();
    my $resa = $ta->join;
    return ($resa, $resb);
  } else {
    return (
      &$codea(),
      &$codeb()
    );
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
      printf STDERR "Execution of: @_\n  confessd with signal %d, %s coredump\n",
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
  confess "Not found: $f" if ! -e $f;

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
  open $hdl, $opn or confess "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
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
  open $hdl, $opn or confess "Can't write to '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

sub make_symal_args {
  # validate and interpret alignment
  my $dirsym = shift;
  my $alitype = undef;
  my $revneeded = 0;
  my $alidiag = "no";
  my $alifinal = "no";
  my $alifinaland = "no";

  if ($dirsym =~ /^rev/) {
    $revneeded = 1;
    $dirsym =~ s/^rev//;
  }

  if ($dirsym eq "int" || $dirsym eq "intersect") {
    $alitype = "intersect";
  } elsif ($dirsym eq "uni" || $dirsym eq "union") {
    $alitype = "union";
  } elsif ($dirsym eq "g" || $dirsym eq "grow") {
    $alitype = "grow";
  } elsif ($dirsym eq "gd" || $dirsym eq "grow-diag") {
    $alitype = "grow";
    $alidiag = "yes";
  } elsif ($dirsym eq "gdf" || $dirsym eq "grow-diag-final") {
    $alitype = "grow";
    $alidiag = "yes";
    $alifinal = "yes";
  } elsif ($dirsym eq "gdfa" || $dirsym eq "grow-diag-final-and") {
    $alitype = "grow";
    $alidiag = "yes";
    $alifinal = "yes";
    $alifinaland = "yes";
  } else {
    return undef;
  }
  # construct symal args
  return [ $revneeded,
    "-alignment='$alitype' -diagonal='$alidiag'"
    ." -final='$alifinal' -both='$alifinaland'"];
}

sub update_vocab {
  my ($txt_file, $oldvcb_file, $newvcb_file) = @_;
  my $oldvcb_hdl = my_open($oldvcb_file);
  my $newvcb_hdl = my_save($newvcb_file);
  my %outvcb;
  my @unk;
  my $lastid = 0;

  # read existing vcb
  while (<$oldvcb_hdl>) {
    chomp;
    my ($id, $word, $count) = split;
    $outvcb{$word} = $id;
    $lastid = $id;
    print $newvcb_hdl join("\t", $id, $word, $count), "\n";
  }
  close $oldvcb_hdl;

  # get unknown words and update the new vcb
  my $txt_hdl = my_open($txt_file);
  while (<$txt_hdl>) {
    chomp;
    my @words = split;
    for my $word (@words) {
      if (! defined $outvcb{$word}) {
        $outvcb{$word} = ++$lastid;
        push @unk, $word;
        print $newvcb_hdl "$lastid\t$word\t1\n";
      }
    }
  }
  close $txt_hdl;
  close $newvcb_hdl;

  return \%outvcb;
}
