#!/usr/bin/perl
# Creates a corpus by combining the specified factors and creating the factors
# if necessary.
# Usage see below.

use strict;
use File::Basename;
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

my @optionspecs = (
  "dump"=>\$dump,
  "d|dir=s" => \$basedir,
  "m|makefile=s" => \$makefile,
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
Options:
  --dump  ... to dump the corpus contents to stdout
  --d|dir=PATH  ... specify a different base directory
  --m|makefile=PATH  ... create factors using a specified Makefile
";
  exit 1;
}

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
if (! -e $corpbasefile) {
  if ($corp =~ /\+/) {
    my $lock = blocking_verbose_lock($corpbasefile);
    print STDERR "Corpus $corp not found in $basedir...\n";
    my @corppieces = split /\+/, $corp;
    print STDERR "...trying to combine it from pieces: @corppieces\n";
    # Collect the intersection of factors as available in all pieces
    my %combfactors = ();
    foreach my $piece (@corppieces) {
      my $infoh = my_open("$basedir/$piece/$lang.info");
      my $info = <$infoh>;
      chomp $info;
      close $infoh;
      foreach my $f (split /\|/, $info) {
        $combfactors{$f}++;
      }
    }
    my @usefactors = ();
    # get the intersection
    foreach my $f (sort keys %combfactors) {
      push @usefactors, $f if $combfactors{$f} == scalar(@corppieces);
    }
    die "There are no common base factors in corpora: @corppieces"
      if 0 == scalar @usefactors;
    print STDERR "Will use these base factors for the combination: @usefactors\n";

    # construct the corpus by concatenating parts
    my $corph = my_save("$basedir/$corp/$lang.gz");
    foreach my $piece (@corppieces) {
      my $sourcefile = augment($piece, $lang, join("+", @usefactors));
      my $inh = my_open($sourcefile);
      print $corph $_ while <$inh>;
      close $inh;
    }
    close $corph;

    # add the signature describing which factors are there
    my $infoh = my_save("$basedir/$corp/$lang.info");
    print $infoh join("|", @usefactors)."\n";
    close $infoh;
    unlock_verbose($lock); # let others know we're finished
  } else {
    die "Corpus not found: $corpbasefile";
  }
}
my $corppathname = augment($corp, $lang, $facts);
# report corpus location or dump the whole corpus
if ($dump) {
  my $hdl = my_open($corppathname);
  print while <$hdl>;
  close $hdl;
} else {
  print $corppathname."\n";
}




sub augment {
  my $corp = shift;
  my $lang = shift;
  my $facts = shift;
  
  my $corpbasefile = "$basedir/$corp/$lang.gz";
  my $corp_stream = my_open($corpbasefile);
  
  # Load corpus header file:
  my $headerfile = "$basedir/$corp/$lang.info";
  open INF, $headerfile or die "Can't read $headerfile";
  my $defined_factors = <INF>;
  close INF;
  chomp $defined_factors;
  
  if (!defined $facts) {
    print STDERR "No augment wished, returning whole $corp/$lang.gz\n";
    my_nonempty($corpbasefile);
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
    my_nonempty($corpbasefile);
    return $corpbasefile;
  }
  
  if (1 == scalar @requested_factors && $requested_factors[0] !~ /^[0-9]+$/) {
    my $factorpathname = construct_projection($corp, $lang, $requested_factors[0]);
    print STDERR "Just one factor wished, returning: $factorpathname\n";
    my_nonempty($factorpathname);
    return $factorpathname;
  }
  
  my $canofacts = join("+", @requested_factors);
  
  my $corpfile = "$corp/combinations/$lang+$canofacts.gz";
  
  my $corppathname = "$basedir/$corpfile";
  
  if (-e $corppathname) {
    my $lock = blocking_verbose_lock($corppathname);
    print STDERR "Corpus '$corp/$lang+$canofacts' seems ready, checking.\n";
    unlock_verbose($lock);
    my_nonempty($corppathname);
    # corpus seems ok, report corpus location
     return $corppathname;
  }

  my %added_factors = map {
          my $factorpathname = construct_projection($corp, $lang, $_);
          my $stream = my_open($factorpathname);
          ( $_, $stream ); # remember the mapping factor name->stream
      } grep { ! /^[0-9]+$/ } @requested_factors;
  
  print STDERR "Locking and writing $corppathname\n";
  my $lock = blocking_verbose_lock($corppathname);
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
  unlock_verbose($lock);
  print STDERR "Done constructing $corp/$lang/$canofacts.\n";
  return $corppathname;
}


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
  } else {
    print STDERR "Generating $factorfile in $basedir\n";
    chdir($basedir) or die "Can't chdir to $basedir";
    safesystem("CORP=$corp LANG=$lang AUGMENT=\"$AUGMENTPATH\" MAKEFILEDIR=\"$MAKEFILEDIR\" AUGMENTMAKEFILE=\"$makefile\" make -f \"$makefile\" $factorfile >&2") or die "Can't make $factorfile";
    print STDERR "Finished generating $factorfile in $basedir\n";
  }
  uncache($factorpathname);
  unlock_verbose($lock);
  return $factorpathname;
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

sub ensure_dir_for_file {
  my $f = shift;
  mkpath(dirname($f));
}

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

sub my_nonempty {
  my $fn = shift;
  my $hdl = my_open($fn);
  my $lineone = <$hdl>;
  die "$fn empty!" if !defined $lineone || $lineone eq "";
  close $hdl;
}
