#!/usr/bin/perl
# Creates a corpus by combining the specified factors and creating the factors
# if necessary.
# Usage see below.

use strict;
use File::Basename;
use File::Temp qw/tempdir/;
use File::Path;
use File::Spec;
use File::NFSLock qw(uncache);
use Fcntl qw(LOCK_EX LOCK_NB LOCK_SH);
use Getopt::Long qw(GetOptionsFromString);

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

my $AUGMENTPATH = File::Spec->rel2abs(__FILE__);
my $basedir = dirname($AUGMENTPATH);
my $makefile = $basedir."/Makefile";
my $dump = 0; # print the corpus contents, not the filename
my $lazy = 0;
my $ignore_blank_lines = 0;
my $sa_index = 0;
my $salm_indexer = undef;
my $tmpdir = "/mnt/h/tmp";

my @optionspecs = (
  "lazy"=>\$lazy, # don't check number of lines, just non-emptiness
  "ignore-blank-lines"=>\$ignore_blank_lines, # don't check for blank lines
  "dump"=>\$dump,
  "d|dir=s" => \$basedir,
  "m|makefile=s" => \$makefile,
  "suffix-array-index" => \$sa_index,
  "salm-indexer=s" => \$salm_indexer,
  "tmpdir=s" => \$tmpdir,
);

# use default options from ./augment.pl.flags, if available
my $default_opt_file = "$basedir/augment.pl.flags";
if (-e $default_opt_file) {
  print STDERR "Loading default options from $default_opt_file\n";
  my $h = my_open($default_opt_file);
  my $defaultoptstr = "";
  $defaultoptstr .= $_ while <$h>;
  close $h;
  GetOptionsFromString($defaultoptstr, @optionspecs)
    or die "Bad options in $default_opt_file";
  $makefile = File::Spec->rel2abs($makefile, dirname($default_opt_file));
}

# overwrite the defaults with environment variables
$makefile = $ENV{"AUGMENTMAKEFILE"} if defined $ENV{"AUGMENTMAKEFILE"};


GetOptions(@optionspecs) or exit 1;

my $MAKEFILEDIR = dirname($makefile);

my $descr = shift;

if (! defined $descr) {
  print STDERR "usage: $0 corpname/lang+fact1+fact2+0+3
Find or construct a factored corpus given a corpus description.
Allowed corpus descriptions:
   corpname/lang+fact1+fact2+0+3
     ... use the corpus 'corpname' in:
           $basedir
         in the language 'lang' and extend it with labelled (fact1, fact2) or
         unlabelled factors (0, 3).
   corp1+corp2/lang+fact1+fact2
     ... will concatenate the common subset of base factors in corp1 and corp2
         into a new directory corp1+corp2 and derive any wished factors
         from this concatenated corpus
   10corpname/lang+fact1+fact2
     ... will concatenate 10 copies of base factors in corpname into a new
         directory 10corpname and derive any wished factors from this
         concatenated corpus; this is a primitive way of increasing priority
         of a corpus, such as a translation dictionary
Options:
  --dump  ... to dump the corpus contents to stdout
  --d|dir=PATH  ... specify a different base directory
  --m|makefile=PATH  ... create factors using a specified Makefile
  --suffix-array-index  ... use SALM to index the corpus and return path to the
                            index
  --salm-indexer=PATH  ... path to salm indexer, e.g.
                            salm-src/./Bin/Linux/Index/IndexSA.O64
  --tmpdir=PATH  ... path to tempdir (used by salm indexer)
";
  exit 1;
}

die "Provide --salm-indexer if you want to construct --suffix-array-index"
  if $sa_index && ! defined $salm_indexer;

my $corp;
my $lang;
my $facts;
if ($descr =~ /^(.+?)\/(.+?)\+(.*)$/) {
  $corp = $1;
  $lang = $2;
  $facts = $3;
} elsif ($descr =~ /^(.+?)\/([^+]+)$/) {
  $corp = $1;
  $lang = $2;
  $facts = undef; # all default factors
} else {
  die "Bad descr format: $descr";
}

print STDERR "Running augment.pl $descr\n";

# Check the corpus file and the header:

my $corpbasefile = "$basedir/$corp/$lang.gz";
my $corpinfofile = "$basedir/$corp/$lang.info";
if (! -e $corpbasefile
  || (-e $corpbasefile && ! -e $corpinfofile && -s $corpbasefile < 10000)) {
  # create if nonexistent or malformed (small, no info file)
  if ($corp =~ /\+/) {
    # combining corpus from various source corpora
    my $lock = blocking_verbose_lock($corpbasefile);
    print STDERR "Corpus $corp not found in $basedir...\n";
    my @corppieces = split /\+/, $corp;
    print STDERR "...trying to combine it from pieces: @corppieces\n";
    # Collect the intersection of factors as available in all pieces
    my $can_use_default_factors = 1; # will directly use lang.gz file, if
                                     # all corpora share the factors (in order)
    my $default_factors = undef;
    my %combfactors = ();
    foreach my $piece (@corppieces) {
      my $infoh = my_open("$basedir/$piece/$lang.info");
      my $info = <$infoh>;
      chomp $info;
      $default_factors = $info if !defined $default_factors;
      $can_use_default_factors = 0 if $default_factors ne $info;
      close $infoh;
      foreach my $f (split /\|/, $info) {
        $combfactors{$f}++;
      }
    }
    my $usefactors = undef;
    if (!$can_use_default_factors) {
      my @usefactors = ();
      # get the intersection
      foreach my $f (sort keys %combfactors) {
        push @usefactors, $f if $combfactors{$f} == scalar(@corppieces);
      }
      die "There are no common base factors in corpora: @corppieces"
        if 0 == scalar @usefactors;
      print STDERR "Will use these base factors for the combination: @usefactors\n";
      $usefactors = join("+", @usefactors);
    }

    # construct the corpus by concatenating parts
    my $corph = my_save("$basedir/$corp/$lang.gz");
    my $linecount = 0;
    foreach my $piece (@corppieces) {
      print STDERR "Constructing $piece/$lang+$usefactors\n";
      my $sourcefile = augment($piece, $lang, $usefactors);
      my $inh = my_open($sourcefile);
      while (<$inh>) {
        $linecount++;
        print $corph $_;
      }
      close $inh;
    }
    close $corph;

    # check or create linecount file
    if (-e "$basedir/$corp/LINECOUNT") {
      my $h = my_open("$basedir/$corp/LINECOUNT");
      my $expected_linecount = <$h>;
      chomp $expected_linecount;
      die "Failed to create valid $corp/$lang; expected $expected_linecount, got $linecount" if $linecount != $expected_linecount;
    } else {
      my $infoh = my_save("$basedir/$corp/LINECOUNT");
      print $infoh "$linecount\n";
      close $infoh;
    }
    # add the signature describing which factors are there
    my $infoh = my_save("$basedir/$corp/$lang.info");
    my $usedfactors = $usefactors;
    $usedfactors = $default_factors if ! defined $usedfactors;
    $usedfactors =~ s/\+/|/g; # use pipe instead of + in info files
    print $infoh "$usedfactors\n";
    close $infoh;
    unlock_verbose($lock); # let others know we're finished
  } elsif ($corp =~ /^(\d+)(.*)/) {
    my $lock = blocking_verbose_lock($corpbasefile);
    print STDERR "Corpus $corp not found in $basedir...\n";
    my $n_copies = $1;
    my $corppiece = $2;
    print STDERR "...trying to combine it from $n_copies copies of: $corppiece\n";
    # Copy all factors available in the piece
    my $infoh = my_open("$basedir/$corppiece/$lang.info");
    my $info = <$infoh>;
    chomp $info;
    close $infoh;
    my @usefactors = split /\|/, $info;
    die "There are no base factors in corpus: $corppiece"
      if 0 == scalar @usefactors;
    print STDERR "Will use these base factors: @usefactors\n";

    # construct the corpus by concatenating copies
    my $corph = my_save("$basedir/$corp/$lang.gz");
    my $sourcefile = augment($corppiece, $lang, join("+", @usefactors));
    my $linecount = 0;
    for(my $i = 0; $i<$n_copies; $i++)
    {
      my $inh = my_open($sourcefile);
      while (<$inh>) {
        $linecount++;
        print $corph $_;
      }
      close $inh;
    }
    close $corph;

    # check or create linecount file
    if (-e "$basedir/$corp/LINECOUNT") {
      my $h = my_open("$basedir/$corp/LINECOUNT");
      my $expected_linecount = <$h>;
      chomp $expected_linecount;
      die "Failed to create valid $corp/$lang; expected $expected_linecount, got $linecount" if $linecount != $expected_linecount;
    } else {
      my $infoh = my_save("$basedir/$corp/LINECOUNT");
      print $infoh "$linecount\n";
      close $infoh;
    }
    # add the signature describing which factors are there
    my $infoh = my_save("$basedir/$corp/$lang.info");
    print $infoh join("|", @usefactors)."\n";
    close $infoh;
    unlock_verbose($lock); # let others know we're finished
  } else {
    print STDERR "Corpus not found: $corpbasefile, will try to construct.\n";
    generate_language("$corp/$lang.gz", $basedir, $corp, $lang);
  }
}
my $corppathname = augment($corp, $lang, $facts);
# report corpus location or dump the whole corpus
if ($dump) {
  my $hdl = my_open($corppathname);
  print while <$hdl>;
  close $hdl;
} elsif ($sa_index) {
  # construct salm index an return the path to it
  my $index_pathname = ensure_salm_index($corppathname);
  print $index_pathname."\n";
} else {
  # default, just print corpus pathname
  print $corppathname."\n";
}
# Ensure that other members of the group are allowed to add factors to directories we may have just created.
# If there are files that the other members created and failed to grant us access, we will get lots of error messages -
# so we are redirecting them to /dev/null.
chdir($basedir);
system('chmod -R g+w . 2>/dev/null');


#------------------------------------------------------------------------------
sub ensure_salm_index {
  my $corpfile = shift;

  my $indexpath = $corpfile;
  $indexpath =~ s/\.gz$/.salm/;
  die "Corpus not gzipped?" if $indexpath eq $corpfile;

  if (-e $indexpath) {
    my $lock = blocking_verbose_lock($indexpath);
    print STDERR "Index '$indexpath' seems ready, checking.\n";
    unlock_verbose($lock);
    my_nonempty($indexpath.".sa_corpus");
    my_nonempty($indexpath.".sa_offset");
    my_nonempty($indexpath.".sa_suffix");
    # corpus seems ok, report corpus location
    return $indexpath;
  }

  print STDERR "Locking and creating $indexpath\n";
  my $lock = blocking_verbose_lock($indexpath);

  if (-e $indexpath) {
    print STDERR "Index '$indexpath' seems ready, checking.\n";
    unlock_verbose($lock);
    my_nonempty($indexpath.".sa_corpus");
    my_nonempty($indexpath.".sa_offset");
    my_nonempty($indexpath.".sa_suffix");
    # corpus seems ok, report corpus location
    return $indexpath;
  }

  my $indexbasename = basename($indexpath);
  my $indexdirname = dirname($indexpath);

  my $tmp = tempdir(DIR=>$tmpdir, CLEANUP=>1);

  # unzip *and* truncate to 255 words at most
  my $inh = my_open($corpfile);
  my $outh = my_save("$tmp/$indexbasename");
  my $nl = 0;
  while (<$inh>) {
    $nl++;
    # dropping any words beyond 255
    s/^((\S+\s){0,254})(.*)$/$1/;
    print $outh $_;
    print STDERR "$nl:Beyond 254 words! Chopping.\n" if defined $3 && $3 ne "";
  }
  close $outh;
  close $inh;
  # safesystem("zcat < $corpfile > $tmp/$indexbasename")
    # or die "Can't gunzip $corpfile";
  safesystem("cd $tmp && $salm_indexer $indexbasename >&2")
    or die "SALM indexer failed for $indexbasename in $tmp";
  safesystem("cp $tmp/$indexbasename.* $indexdirname")
    or die "Failed to copy the finished index back";

  my $h = my_save($indexpath);
  print $h "Created by $salm_indexer via augment.pl";
  close $h;
  unlock_verbose($lock);

  return $indexpath;
}



#------------------------------------------------------------------------------
sub augment {
  my $corp = shift;
  my $lang = shift;
  my $facts = shift;

  my $corpbasefile = "$basedir/$corp/$lang.gz";
  my $corp_stream = my_open($corpbasefile);

  # Read expected line count
  if (! -e "$basedir/$corp/LINECOUNT") {
    print STDERR ("Upon creating new folder with corpus you must also call:\n");
    print STDERR ("\tzcat corpus.gz | wc -l > LINECOUNT\n");
    print STDERR ("augment.pl checks the invariant that all languages and factors have this number of lines.\n");
    safesystem("zcat $basedir/$corp/$lang.gz | wc -l $basedir/$corp/LINECOUNT") or die;
  }
  my $h = my_open("$basedir/$corp/LINECOUNT");
  my $corplinecount = <$h>;
  chomp $corplinecount;
  close $h;
  print STDERR "The corpus $corp/* needs to contain $corplinecount lines.\n";

  # Load corpus header file:
  my $headerfile = "$basedir/$corp/$lang.info";
  open INF, $headerfile or die "Can't read $headerfile";
  my $defined_factors = <INF>;
  close INF;
  chomp $defined_factors;

  if (!defined $facts) {
    print STDERR "No augment wished, returning whole $corp/$lang.gz\n";
    validate($corpbasefile, $corplinecount);
    return $corpbasefile;
  }

  my $fid = 0;
  my %defined_factor;
  foreach my $defined_factor (split /\|/, $defined_factors) {
    $defined_factor{$defined_factor} = $fid;
    $fid++;
  }

  # Convert factors name to canonical:
  my @requested_factors = map {
        defined $defined_factor{$_} ? $defined_factor{$_} : $_
      } split /\+/, $facts;

  if ( scalar(@requested_factors) == keys(%defined_factor)
    && join(" ", 0..($fid-1)) eq join(" ", @requested_factors) ) {
    print STDERR "Wished exactly the full corpus, returning $corp/$lang.gz\n";
    validate($corpbasefile, $corplinecount);
    return $corpbasefile;
  }

  if (1 == scalar @requested_factors && $requested_factors[0] !~ /^[0-9]+$/) {
    my $factorpathname = construct_projection($corp, $lang, $requested_factors[0]);
    print STDERR "Just one factor wished, returning: $factorpathname\n";
    validate($factorpathname, $corplinecount);
    return $factorpathname;
  }

  my $canofacts = join("+", @requested_factors);

  my $corpfile = "$corp/combinations/$lang+$canofacts.gz";

  my $corppathname = "$basedir/$corpfile";

  if (-e $corppathname) {
    my $lock = blocking_verbose_lock($corppathname);
    print STDERR "Corpus '$corp/$lang+$canofacts' seems ready, checking.\n";
    validate($corppathname, $corplinecount);
    # corpus seems ok, report corpus location
    unlock_verbose($lock);
    return $corppathname;
  }

  # I had to introduce the additional variable @named_requested_factors because
  # perl would modify (discard) them in place due to something I don't
  # understand.
  my @named_requested_factors = grep { ! /^[0-9]+$/ } @requested_factors;
  my %added_factors = map {
          my $f = $_;
          my $factorpathname = construct_projection($corp, $lang, $f);
          my $stream = my_open($factorpathname);
          # print STDERR "Opened $factorpathname:  $f  -->  $stream\n";
          ( $f, $stream ); # remember the mapping factor name->stream
      } @named_requested_factors;

  print STDERR "Locking and writing $corppathname\n";
  # print STDERR "Requested factors: ".join(", ", @requested_factors)."\n";
  # print STDERR "Adding factors: ".join(", ", keys %added_factors)."\n";
  my $lock = blocking_verbose_lock($corppathname);
  if (-e $corppathname) {
    print STDERR "Seems ready: $corppathname\n";
  } else {
    my $outstream = my_save($corppathname);

    my $nr=0;
    while (<$corp_stream>) {
      $nr++;
      print STDERR "." if $nr % 10000 == 0;
      print STDERR "($nr)" if $nr % 100000 == 0;
      chomp;
      my @intokens = split / +/;
      # load lines of corresponding streams and ensure equal number of words
      my %lines_of_extratoks;
      foreach my $factor (keys %added_factors) {
        my $line = readline($added_factors{$factor});
        # print STDERR "Got line from $factor ($added_factors{$factor}): $line";
        die "Additional factor file for $factor contains too few sentences!"
          if !defined $line;
        chomp($line);
        my @toks = split / +/, $line;
        die "Incompatible number of words in factor $factor on line $nr."
          if $#toks != $#intokens;
        $lines_of_extratoks{$factor} = \@toks;
      }

      # for every token, print the factors in the order as user wished
      for(my $i=0; $i<=$#intokens; $i++) {
        my $token = $intokens[$i];
        my @outtoken = ();
        my @factors = split /\|/, $token;
        # print STDERR "Token: $token\n";
        foreach my $name (@requested_factors) {
          my $f = undef;
          if ($name =~ /^[0-9]+$/o) {
            # numeric factors should be copied from original corpus
            $f = $factors[$name];
            die "Missed factor $name in $token on line $nr"
              if !defined $f || $f eq "";
          } else {
            # named factors should be obtained from the streams
            $f = $lines_of_extratoks{$name}->[$i];
            die "Missed factor $name on line $nr"
              if !defined $f || $f eq "";
          }
          # print STDERR "  Factor $name: $f\n";
          push @outtoken, $f;
        }
        print $outstream " " if $i != 0;
        print $outstream join("|", @outtoken);
      }
      print $outstream "\n";
    }
    close $corp_stream;
    close $outstream;
    uncache $corppathname;
    ensure_linecount($corppathname, $nr);
  }
  unlock_verbose($lock);
  print STDERR "Done constructing $corp/$lang/$canofacts.\n";
  return $corppathname;
}


#------------------------------------------------------------------------------
sub blocking_verbose_lock {
  # in readonly mode, block until an existing lockfile vanishes and return undef
  # in regular mode, block on creating lockfile..
  my $fn = shift;
  my $lock = undef;
  my $authfile = $fn.".lock";
  if (-e $authfile) {
    print STDERR "Waiting for ".`cat $authfile 2>/dev/null`;
  }
  ensure_dir_for_file($fn);
  if (! -w dirname($authfile)) {
    sleep(30) while -e $authfile;
    die "Won't create lockfile in readonly mode for $fn"
      if ! -e $fn;
    return undef;
  }
  my $msg = 0;
  while (! ($lock = File::NFSLock->new($fn, LOCK_EX, 10,30*60))) {
    # waiting
    print STDERR "Waiting for lockfile for $fn..." if !$msg;
    $msg = 1;
  }
  my $authstream = my_save($authfile);
  my $hostname = `hostname`; chomp($hostname);
  print $authstream "$ENV{USER}\@$hostname:$$\n";
  close $authstream;
  return {lock=>$lock, fn=>$fn};
}

sub unlock_verbose {
  my $lock = shift;
  return if !defined $lock;
  unlink $lock->{fn}.".lock" if -e $lock->{fn}.".lock";
  $lock->{lock}->unlock();
}


#------------------------------------------------------------------------------
sub construct_projection {
  my $corp = shift;
  my $lang = shift;
  my $fact = shift;

  # this factor should be available in a file:
  my $factorfile = "$corp/$lang.factors/$fact.gz";
  my $factorpathname = $basedir."/".$factorfile;
  my $lock = blocking_verbose_lock($factorpathname);
  if (-e $factorpathname) {
    print STDERR "Using old $factorfile\n";
    # If a previous run of augment.pl failed, the existing factor may be empty.
    # If so, erase the empty factor and try to recreate it.
    my $nl = count_lines($factorpathname);
    if($nl) {
      print STDERR "Old $factorfile has ", count_lines($factorpathname), " lines.\n";
    } else {
      print STDERR "Old $factorfile is empty, erasing and recreating.\n";
      unlink($factorpathname) or die "Can't remove $factorpathname: $!\n";
      generate_factor($factorfile, $basedir, $corp, $lang);
    }
  } else {
    generate_factor($factorfile, $basedir, $corp, $lang);
  }
  uncache($factorpathname);
  unlock_verbose($lock);
  return $factorpathname;
}


#------------------------------------------------------------------------------
sub generate_factor {
  my $factorfile = shift;
  my $basedir = shift;
  my $corp = shift;
  my $lang = shift;

  print STDERR "Generating factor $factorfile in $basedir\n";
  chdir($basedir) or die "Can't chdir to $basedir";
  safesystem("CORP=$corp LANG=$lang AUGMENT=\"$AUGMENTPATH\" MAKEFILEDIR=\"$MAKEFILEDIR\" AUGMENTMAKEFILE=\"$makefile\" make -f \"$makefile\" $factorfile >&2") or die "Can't make $factorfile";
  print STDERR "Finished generating $factorfile in $basedir\n";
}


#------------------------------------------------------------------------------
sub generate_language {
  my $corpusfile = shift;
  my $basedir = shift;
  my $corp = shift;
  my $lang = shift;

  print STDERR "Generating language $corpusfile in $basedir\n";
  chdir($basedir) or die "Can't chdir to $basedir";
  safesystem("CORP=$corp LANG=$lang AUGMENT=\"$AUGMENTPATH\" MAKEFILEDIR=\"$MAKEFILEDIR\" AUGMENTMAKEFILE=\"$makefile\" make -f \"$makefile\" $corpusfile.generate_language >&2") or die "Can't make $corpusfile";
  print STDERR "Finished generating language $corpusfile in $basedir\n";
}


#------------------------------------------------------------------------------
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


#------------------------------------------------------------------------------
sub ensure_dir_for_file {
  my $f = shift;
  mkpath(dirname($f));
}


#------------------------------------------------------------------------------
sub my_save {
  my $f = shift;

  ensure_dir_for_file($f);
  my $opn;
  my $hdl;
  if ($f =~ /\.gz$/) {
    $opn = "| gzip -c > $f";
  } elsif ($f =~ /\.bz2$/) {
    $opn = "| bzip2 > $f";
  } else {
    $opn = "> $f";
  }
  open $hdl, $opn or die "Can't write to '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}


#------------------------------------------------------------------------------
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


#------------------------------------------------------------------------------
sub validate {
  my $corpbasefile = shift;
  my $needlinescount = shift;

  if ($lazy) {
    my_nonempty($corpbasefile);
  } else {
    ensure_linecount($corpbasefile, $needlinescount);
  }
}


#------------------------------------------------------------------------------
sub my_nonempty {
  my $fn = shift;
  my $hdl = my_open($fn);
  my $lineone = <$hdl>;
  die "$fn empty!" if !defined $lineone || $lineone eq "";
  close $hdl;
}


#------------------------------------------------------------------------------
sub ensure_linecount {
  my $fn = shift;
  my $reqnr = shift;
  my $nr = count_lines($fn);
  die "$fn:Expected $reqnr lines, got $nr." if $reqnr != $nr;
}


#------------------------------------------------------------------------------
sub count_lines {
  my $fn = shift;
  my $linecounttimestamp = $fn.".linecount_ok";
  if (-e $linecounttimestamp
    && (stat($linecounttimestamp))[9] > (stat($fn))[9] ) {
    my $h = my_open($linecounttimestamp);
    my $cnt = <$h>;
    chomp $cnt;
    die "Bad linecount in $linecounttimestamp" if $cnt !~ /^[0-9]+$/;
    close $h;
    # print STDERR "Trusting existing count $cnt for $fn.\n";
    return $cnt;
  }
  print STDERR "Counting lines of $fn.\n";
  my $hdl = my_open($fn);
  my $nr = 0;
  while (<$hdl>) {
    $nr++;
    die "$fn:$nr:Blank line." if !$ignore_blank_lines && /^\s*$/;
    # Windows-style line breaks (CR LF instead of Linux-style LF only) are dangerous for Giza.
    die "$fn:$nr:CR (\\r) can kill Giza, get rid of it!" if /\r/;
    # No tabs and blank characters other than space and LF (line break).
    my $x = $_;
    $x =~ s/[ \n]//g;
    die "$fn:$nr:Blank character other than space or LF." if $x =~ /\s/;
    # Two consecutive spaces could be interpreted as empty tokens by some programs, which is dangerous.
    die "$fn:$nr:Two or more consecutive spaces." if /\s\s/;
    unless (m/\n$/) {
      print STDERR "WARNING: last line ($fn:$nr) not terminated by LF which may cause the 'wc -l' command not to count it.\n";
    }
  }
  close $hdl;
  my $outh = my_save($linecounttimestamp);
  print $outh "$nr\n";
  close $outh;
  return $nr;
}
