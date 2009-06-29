#!/usr/bin/perl

print STDERR "running prepare_for_flm.pl...\n";

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

$source = shift;
$target = shift;

print STDERR "target: $target\n";
$SOURCE = my_open($source);
$TARGET = my_save($target);

@FACTORS = ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p');

while ($radek = <$SOURCE>)
{
  chomp($radek);
  while ($radek =~ m/^(\s*)(\S+)(\s*.*)$/)
  {
    $ws1 = $1;
    $token = $2;
		$zbytek = $3;

		print $TARGET $ws1;		

		$i = 0;
		while ($token =~ /^\|?([^|]+)(.*)$/ )
		{
			$token = $2;
			$factor = $1;
      if ($i == 0)
			{
			  print $TARGET $FACTORS[$i]."-$factor";
			}
      else
			{
			  print $TARGET ":".$FACTORS[$i]."-$factor";
			}
			$i++;
		}

	$radek = $zbytek;

  }
	print $TARGET "\n";
}

close $TARGET;
close $SOURCE;

print STDERR "prepare_for_flm.pl finished...\n";


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
