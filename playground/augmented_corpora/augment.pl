#!/usr/bin/perl
# Creates a corpus by combining the specified factors and creating the factors
# if necessary.
# Allowed descriptions:
#    corpname/lang+fact1+fact2+0
#    corpname+fact1+fact2 --lang=lang  # not yet implemented

use strict;
use File::Basename;
use File::Spec;
use File::NFSLock qw(uncache);
use Fcntl qw(LOCK_EX LOCK_NB LOCK_SH);
use Getopt::Long;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

my $basedir = dirname(File::Spec->rel2abs(__FILE__));

my $dump = 0; # print the corpus contents, not the filename
GetOptions(
  "dump"=>\$dump,
) or exit 1;

my $descr = shift;

if (! defined $descr) {
  print STDERR "usage: $0 corpname/lang+fact1+fact2+0
  This will use the corpus 'corpname' in:
    $basedir
  in the language 'lang' and extend it with labelled (fact1, fact2) or
  unlabelled factors (0).
  Finally, it will emit the pathname to that corpus
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
die "Corpus not found: $corpbasefile" if ! -e $corpbasefile;
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
  emit($corpbasefile);
  exit 0;
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
  emit($corpbasefile);
  exit 0;
}

if (1 == scalar @requested_factors && $requested_factors[0] !~ /^[0-9]+$/) {
  my $factorpathname = construct_projection($corp, $lang, $requested_factors[0]);
  print STDERR "Just one factor wished, returning: $factorpathname\n";
  my_nonempty($factorpathname);
  emit($factorpathname);
  exit 0;
}

my $canofacts = join("+", @requested_factors);

my $corpfile = "$corp/combinations/$lang+$canofacts.gz";

my $corppathname = "$basedir/$corpfile";

ensure_dir_for_file($corppathname);

if (-e $corppathname) {
  my $lock = blocking_verbose_lock($corppathname);
  print STDERR "Corpus '$descr' seems ready, checking.\n";
  unlock_verbose($lock);
  my_nonempty($corppathname);
  # corpus seems ok, report corpus location
  emit($corppathname);
  exit 0;
}

sub blocking_verbose_lock {
  my $fn = shift;
  my $lock = undef;
  my $authfile = $fn.".lock";
  if (-e $authfile) {
    print STDERR "Waiting for ".`cat $authfile 2>/dev/null`;
  }
  while (! ($lock = File::NFSLock->new($fn, LOCK_EX, 10,30*60))) {
    # waiting
  }
  my $authstream = my_save($authfile);
  my $hostname = `hostname`; chomp($hostname);
  print $authstream "$hostname:$$\n";
  close $authstream;
  return {lock=>$lock, fn=>$fn};
}

sub unlock_verbose {
  my $lock = shift;
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
  ensure_dir_for_file($factorpathname);
  my $lock = blocking_verbose_lock($factorpathname);
  if (-e $factorpathname) {
    print STDERR "Using old $factorfile\n";
  } else {
    print STDERR "Generating $factorfile in $basedir\n";
    chdir($basedir) or die "Can't chdir to $basedir";
    safesystem("CORP=$corp LANG=$lang make $factorfile >&2") or die "Can't make $factorfile";
    print STDERR "Finished generating $factorfile in $basedir\n";
  }
  uncache($factorpathname);
  unlock_verbose($lock);
  return $factorpathname;
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
  my @intokens = split / /;
  # load lines of corresponding streams and ensure equal number of words
  my %lines_of_extratoks;
  foreach my $factor (keys %added_factors) {
    my $line = readline($added_factors{$factor});
    die "Additional factor file for $factor contains too few sentences!"
      if !defined $line;
    chomp($line);
    my @toks = split / /, $line;
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
print STDERR "Done.\n";

# report corpus location
emit($corppathname);

sub emit {
  my $filename = shift;
  if ($dump) {
    my $hdl = my_open($filename);
    print while <$hdl>;
    close $hdl;
  } else {
    print $filename."\n";
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

sub ensure_dir_for_file {
  my $f = shift;
  my $dir = $f;
  $dir =~ s/\/[^\/]*$//;
  safesystem(qw(mkdir -p), $dir) or die "Can't create dir for $f";
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
