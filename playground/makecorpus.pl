#!/usr/bin/perl
# This script cooperates with eman.seeds/makecorpus (and possibly other eman
# seeds) and constructs factored corpus of a given specification within eman
# framework of steps.
# Upon success, it prints just one line with three columns:
#   stepname ... the name of the eman step, where the wished corpus was created
#   filename ... the file in the step directory
#   column   ... the column in the file (if -1, take the whole file)

use strict;
use warnings;

use Getopt::Long;
use File::Path;
use File::Basename;
use YAML;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $MYPATH = File::Spec->rel2abs(__FILE__);
my $mydir = dirname($MYPATH);

my $indexfile = "makecorpus.index";
my $verbose = 0;
my $reindex = 0;
my $init = 0;
my $start = 0;
my $wait = 0;
my $dumpcmd = 0;
my $dump = 0;
my $fakeno = 1; # the step number when for dry-runs

GetOptions(
  "reindex!" => \$reindex,
  "init!" => \$init,
  "start!" => \$start,
  "wait!" => \$wait,
  "cmd!" => \$dumpcmd,
  "dump!" => \$dump,
  "verbose!" => \$verbose,
) or exit 1;

my $descr = shift;

if (! defined $descr) {
  print STDERR "usage: $0 corpname/lang+fact1+fact2+fact3
Find or construct a factored corpus given a corpus description.
Allowed corpus descriptions:
   corpname/lang+fact1+fact2
     ... use the corpus 'corpname' in the language 'lang' and extend it with
         factors labelled fact1 and fact2
   corp1+corp2/lang+fact1+fact2
     ... concatenate the language lang of corpus 1 and 2 and emit the wished
         factors
Options:
  (nothing)  ... dry run: show which eman steps would be prepared
  --init     ... real run: use eman to init the steps
  --start    ... also start the newly created steps, implies --init
  --wait     ... wait for the final step to finish, implies --start
  --cmd      ... emit a tiny shell script that dumps the corpus to stdout,
                 implies --wait
  --dump     ... dump the corpus to stdout, implies --wait

";
  exit 1;
}

# switch implications
$wait = 1 if $dumpcmd || $dump;
$start = 1 if $wait;
$init = 1 if $start; # start implies to init

die "Incompatible requests: --dump and --cmd" if $dumpcmd && $dump;


# constants:
my $yes_derived = 1;
my $not_derived = 0;


# first construct an index of corpora bits
my $index;
# $index->{corpname}->{language}->{fact}
#    = {   stepname=>the_directory_name,
#          filename=>filename_within_the_stepname,
#          column=>column_within_the_file; -1 could indicate the whole file,
#          factind=>factor_index_within_the_file, -1 indicates the whole file
#          linecount=>number_of_lines}
# where 'fact' *can* be a specification of several factors: 
my $err = 0;

# chdir to main dir
chdir($mydir) or die "Failed to chdir to $mydir";

if ( ! -e $indexfile || $reindex ) {
  print STDERR "Indexing...\n" if $verbose;
  open INDFILES, "find -maxdepth 2 -name corpman.info |"
    or die "Can't search for corpora";
  while (<INDFILES>) {
    chomp;
    my $fn = $_;
    my @dirs = split /\//, $fn, 2;
    my $stepname = undef;
    foreach my $dir (split /\//, $fn) {
      if ($dir =~ /^s\..*\.[0-9]{8}-[0-9]{4}$/) {
        $stepname = $dir;
        last;
      }
    }
    die "Failed to guess step name from $fn" if !defined $stepname;
    my $status = load_step_status($stepname);
    next if $status !~ /INITED|PREPARED|RUNNING|WAITING|DONE/;
      # skip all bad steps
    my $text = load_file($fn);
    foreach my $line (split /\n/, $text) {
      next if $line eq "";
      my ($filename, $column, $corpname, $lang, $facts, $linecount, $mayderived)
        = split /\t/, trim($line);
      die "Bad entry $fn: $line" if $linecount !~ /^[0-9]+$/;
      add_entry_incl_entries_of_separate_factors(
        $corpname, $lang, $facts, $stepname, $filename, $column, $linecount, $mayderived);
    }
  }
  close INDFILES;
  exit 1 if $err;
  saveidx($index);
} else {
  # load existing index
  $index = loadidx();
}


# read rules from makecorpus.rules
my $rulestext = load_file("makecorpus.rules");
my $rules;
# $rules->{outlang}->{outfacts} = {
#   inlang=>input language
#   infacts=>input factors
#   command=>the command to run
# }
foreach my $line (split /\n/, $rulestext) {
  next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
  my ($inlang, $infacts, $outlang, $outfacts, $command)
    = split /\t/, trim($line);
  if ($inlang eq "*" xor $outlang eq "*") {
    print STDERR "Bad rule: either none or both input and output languages have to be '*': $line\n";
    $err++;
  }
  $infacts =~ s/\|/+/g;
  $outfacts =~ s/\|/+/g;
  # for the construction of all factors at once
  add_rule($outlang, $outfacts, {
    'inlang'=>$inlang,
    'infacts'=>$infacts,
    'command'=>$command,
  });
  if ($outfacts =~ /[+\|]/) {
    # add also rules for two-step construction
    my $f = 0;
    foreach my $outfact (split /[+\|]/, $outfacts) {
      add_rule($outlang, $outfact, {
        'inlang'=>$outlang,
        'infacts'=>$outfacts,
        # 'command'=>"reduce_factors.pl $f",
            # no command, this will be lazy-extracted
      });
      $f++;
    }
  }
}

exit 1 if $err;


my $corp;
my $lang;
my $facts;
if ($descr =~ /^(.+?)\/(.+?)\+(.*)$/) {
  $corp = $1;
  $lang = $2;
  $facts = $3;
} else {
 die "Bad descr format: $descr";
}

$facts =~ s/\|/+/g;


my ($stepname, $filename, $column)
  = build_exact_factors($corp, $lang, $facts);

if ($wait) {
  my $status = load_step_status($stepname);
  if ($status ne "DONE") {
    safesystem("eman wait $stepname")
      or die "Failed to wait for $stepname to finish."
  }
}

if ($dumpcmd) {
  my $maygunzip = ($filename =~ /\.gz$/ ? "zcat" : "cat");
  print "$maygunzip $mydir/$stepname/$filename";
  print " | cut -f $column" if $column != -1;
  print "\n";
} elsif ($dump) {
  my $h = my_open("$mydir/$stepname/$filename");
  if ($column == -1) {
    print while <$h>;
  } else {
    while (<$h>) {
      chomp;
      my @cols = split /\t/;
      print $cols[$column-1], "\n";
    }
  }
  close $h;
} else {
  # print the details: stepname, filename and column
  print $stepname, "\t", $filename, "\t", $column, "\n";
}

sub build_exact_factors {
  # runs lazy_build and extracts the required factor if necessary
  my $entry = lazy_build($corp, $lang, $facts);
  print STDERR "Called build_exact_factors @_\n" if $verbose;
  if ($entry->{"factind"} == -1) {
    # great, the given column contains exactly the factors we asked for
    return ($entry->{"stepname"}, $entry->{"filename"}, $entry->{"column"});
  } else {
    # not quite, we need to restrict the given factor
    my $stepname = run_or_fake_corpman_step("DEPS=$entry->{stepname} RUN_COMMAND='cat' STEPNAME=$entry->{stepname} FILENAME=$entry->{filename} COLUMN=$entry->{column} FACTOR=$entry->{factind} OUTCORP=$corp OUTLANG=$lang OUTFACTS='$facts' OUTLINECOUNT=$entry->{linecount} eman init corpman", [$entry->{"stepname"}]);
    my $filename = "corpus.txt.gz";
    my $column = -1;
    return ($stepname, $filename, $column);
  }
}


sub lazy_build {
  # build the specified corpus
  # return stepname, filename, column and -1 (if the requested factors are
  # exactly there) or the factor number of the *single* factor to pick
  my ($corp, $lang, $facts) = @_;
  print STDERR "Called lazy_build @_\n" if $verbose;

  # check if the whole corpus happens to be ready
  my $entry = $index->{$corp}->{$lang}->{$facts};
  return $entry if defined $entry;
    # here is the laziness: $entry->{factind} may be != -1, i.e. asking to
    # extract a factor

  if ($corp =~ /\+/) {
    # The corpus needs to be constructed by concatenation
    # First recursively build all parts
    my $linecount = 0;
    my @parts = ();
    my @deps = (); # which steps should we wait for
    foreach my $subcorp (split /\+/, $corp) {
      my $subentry = lazy_build($subcorp, $lang, $facts);
      $linecount += $subentry->{"linecount"};
      my $pathname = "../$subentry->{stepname}/$subentry->{filename}";
        # XXX should ask eman to locate the stepdir
      my $subcolumn = $subentry->{"column"};
      my $subfactind = $subentry->{"factind"};
      my $cmd = "zcat $pathname";
      $cmd .= " | cut -f $subcolumn" if $subcolumn != -1;
      $cmd .= " | reduce_factors.pl $subfactind" if $subfactind != -1;
      push @parts, $cmd;
      push @deps, $subentry->{"stepname"};
    }
    my $stepname = run_or_fake_corpman_step("DEPS='@deps' TAKE_FROM_COMMAND='("
      .join("; ", @parts)
      .")' OUTCORP=$corp OUTLANG=$lang OUTFACTS='$facts' OUTLINECOUNT=$linecount eman init corpman", \@deps);
    my $filename = "corpus.txt.gz";
    my $column = -1;

    # add to index for further use 
    return add_entry_incl_entries_of_separate_factors(
      $corp, $lang, $facts, $stepname, $filename, $column, $linecount, $yes_derived);
  }

  # the required sequence of factors, or the single factor is not available,
  # we must build it

  # if we're asked for a single factor, we know we must use rules
  # if we're asked for multiple factors, there *may* be a chance it's just a
  # different permutation of the existing ones...
  #   but we will simply lazy_build all necessary factors and combine them

  # need to construct corpus from parts
  if ($facts =~ /[\|+]/) {
    # check if this set of factors can be constructed using a rule
    return build_using_rules($corp, $lang, $facts)
      if defined $rules->{$lang}->{$facts};

    # no, there is no rule for this particular set of factors, construct by
    # combination
    my $linecount = undef;
    # construct by combining corpus parts
    my @parts = ();
    my @deps = (); # which steps should we wait for
    foreach my $fact (split /[\|+]/, $facts) {
      # recursion:
      my $subentry = lazy_build($corp, $lang, $fact);

      die "Incompatible linecount when constructing $corp/$lang+$facts from parts: $linecount vs. $subentry->{linecount}, the latter for $fact"
        if defined $linecount && $linecount != $subentry->{"linecount"};
      $linecount = $subentry->{"linecount"};

      my $pathname = "../$subentry->{stepname}/$subentry->{filename}";
        # XXX should ask eman to locate the stepdir
      push @parts, "$pathname $subentry->{column} $subentry->{factind}";
      push @deps, $subentry->{"stepname"};
    }
    # build a step that combines all these

    my $stepname = run_or_fake_corpman_step("DEPS='@deps' COMBINE_PARTS='@parts' OUTCORP=$corp OUTLANG=$lang OUTFACTS='$facts' OUTLINECOUNT=$linecount eman init corpman", \@deps);
    my $filename = "corpus.txt.gz";
    my $column = -1;

    # add to index for further use 
    return add_entry_incl_entries_of_separate_factors(
      $corp, $lang, $facts, $stepname, $filename, $column, $linecount, $yes_derived);
  }

  # $facts is now just a single factor and we surely know we need to search
  # rules to construct it
  return build_using_rules($corp, $lang, $facts);
}

sub build_using_rules {
  my ($corp, $lang, $facts) = @_;
  print STDERR "Called build_using_rules @_\n" if $verbose;

  my $rule = $rules->{$lang}->{$facts};
  $rule = $rules->{'*'}->{$facts} if ! defined $rule;
  die "No rule to make $lang+$facts."
    if !defined $rule;

  my $useinlang = $rule->{'inlang'};
  $useinlang = $lang if $useinlang eq "*";
  # build the input corpus for the rule
  my $subentry = lazy_build($corp, $useinlang, $rule->{"infacts"});

  return lazy_build($corp, $lang, $facts)
    if !defined $rule->{'command'};

  # apply the rule
  my $linecount = $subentry->{"linecount"};
  my $stepname = run_or_fake_corpman_step("DEPS='$subentry->{stepname}' RUN_COMMAND='$rule->{command}' STEPNAME=$subentry->{stepname} FILENAME=$subentry->{filename} COLUMN=$subentry->{column} FACTOR=$subentry->{factind} OUTCORP=$corp OUTLANG=$lang OUTFACTS='$facts' OUTLINECOUNT=$linecount eman init corpman", [$subentry->{"stepname"}]);
  my $filename = "corpus.txt.gz";
  my $column = -1;

  # add to index for further use 
  return add_entry_incl_entries_of_separate_factors(
    $corp, $lang, $facts, $stepname, $filename, $column, $linecount, $yes_derived);
}


sub run_or_fake_corpman_step {
  my $command = shift;
  my $deps = shift; # deps to wait for

  if (!$init) {
    my $fakeoutstep = "s.fake.".($fakeno++);
    print STDERR $fakeoutstep, ": ", $command, "\n";
    return $fakeoutstep;
  }
  # we indeed issue the command to prepare the corpus
  # first invalidate our index, if it exists
  unlink("$mydir/$indexfile");
  $command = "cd $mydir && $command";
  $command .= " --start" if $start;
  print STDERR "EXECUTING: $command\n" if $verbose;
  $command .= " 2>&1";
  my $out = `$command`;
  print STDERR "--eman-stdout--\n$out\n--end-of-eman-stdout--\n" if $verbose;
  if ($out =~ /Inited: (s\.corpman\..*)/) {
    my $outstep = $1;
    print STDERR "corpman inited: $outstep\n";
    return $outstep;
  } else {
    print STDERR "Failed to get stepname!\n";
    print STDERR "Launched: $command\n";
    print STDERR "Got:\n$out\n--end-of-eman-stdout--\n";
    exit 1;
  }
}



sub add_rule {
  my ($outlang, $outfacts, $newrule) = @_;
  $outfacts =~ s/\|/+/g;
  my $oldrule = $rules->{$outlang}->{$outfacts};
  if (defined $oldrule) {
    print STDERR "Conflicting rules to produce $outlang+$outfacts: "
      ."from $newrule->{inlang}+$newrule->{infacts}"
      ." vs. "
      ."from $oldrule->{inlang}+$oldrule->{infacts}\n";
    $err = 1;
  } else {
    $rules->{$outlang}->{$outfacts} = $newrule;
  }
}



sub add_entry_incl_entries_of_separate_factors {
  my ($corpname, $lang, $facts, $stepname, $filename, $column, $linecount, $mayderived) = @_;
  my $newentry = {
    "stepname" => $stepname,
    "filename" => $filename,
    "column" => $column,
    "factind" => -1,
    "linecount" => $linecount,
  };
  add_entry($corpname, $lang, $facts, $newentry, $mayderived);

  if ($facts =~ /[+\|]/) {
    # add also individual factors to support construction of the corpus
    my $factind = -1;
    foreach my $fact (split /[+\|]/, $facts) {
      $factind++;
      add_entry($corpname, $lang, $fact,
        {
          "stepname" => $stepname,
          "filename" => $filename,
          "column" => $column,
          "factind" => $factind,
          "linecount" => $linecount,
        },
        $yes_derived
        );
    }
  }
  return $newentry;
}

sub add_entry {
  # Add a corpus to the index avoiding duplicates.
  # This *could* be restricted by some other variables like eman select...
  my ($corpname, $lang, $facts, $newentry, $isderived) = @_;
  $facts =~ s/\|/+/g;

  print STDERR "Adding $corpname/$lang+$facts: "
      ."$newentry->{stepname}/$newentry->{filename}:$newentry->{column}"
      ."\n" if $verbose;
  my $oldentry = $index->{$corpname}->{$lang}->{$facts};
  if (defined $oldentry && !$isderived) {
    print STDERR "Conflicing sources for $corpname/$lang+$facts: "
      ."$newentry->{stepname}/$newentry->{filename}:$newentry->{column}"
      ." vs "
      ."$oldentry->{stepname}/$oldentry->{filename}:$oldentry->{column}\n";
    $err = 1;
  } else {
    $index->{$corpname}->{$lang}->{$facts} = $newentry;
  }
}



sub my_open {
  my $f = shift;
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


# Run a command very safely.
# Synopsis: safesystem(qw(echo hello)) or die;
sub safesystem {
    # print STDERR "Executing: @_\n";
    system(@_);
    if ($? == -1) {
        print STDERR "Failed to execute: @_\n  $!\n";
        exit(1);
    } elsif ($? & 127) {
        printf STDERR "Execution of: @_\n  died with signal %d, %s coredump\n",
            ($? & 127),  ($? & 128) ? 'with' : 'without';
        exit(1);
    } else {
        my $exitcode = $? >> 8;
        print STDERR "Exit code: $exitcode\n" if $exitcode;
        return ! $exitcode;
    }
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
  open $hdl, $opn or die "Can't write to '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

sub load_file {
  my $fn = shift;
  my $out = "";
  my $h = my_open($fn);
  $out .= $_ while <$h>;
  close $h if $fn ne "-";
  return $out;
}

sub save_file {
  my $fn = shift;
  my $text = shift;
  my $h = my_save($fn);
  print $h $text;
  close $h;
}

sub trim {
  my $s = shift;
  $s =~ s/ +\t/\t/g;
  $s =~ s/\t +/\t/g;
  $s =~ s/^ +//;
  $s =~ s/ +$//;
  return $s;
}

sub load_step_status {
  my $stepname = shift;
  my $status = load_file($stepname."/eman.status");
  chomp $status;
  return $status;
}


sub loadidx {
  # load the index file and hash it there and back
  my $idx;
  if (-e $indexfile) {
    $idx = Load(load_file($indexfile)."\n"); # YAML to Load the string
  }
  return $idx;
}
sub saveidx {
  my $idx = shift;
  my $h = my_save($indexfile);
  print $h YAML::Dump($idx);
  close $h;
}
