#!/usr/bin/perl
# changes moses.ini for the purposes of system combination:
# - replaces all t-table files with a single fake ttable
# - adds one more LM based on hypotheses
# - modifies weight counts accordingly

use strict;
use Getopt::Long;

my $default_weight_l = 0.5;
my $linkparamcount = undef;

GetOptions(
  "link-param-count=i" => \$linkparamcount,
) or exit 1;

my $emptyttablefile = shift;
my $hyplmfile = shift;
my $hyplmorder = shift;

$hyplmorder = 3 if !defined $hyplmorder;

die "usage!" if !defined $emptyttablefile || !defined $hyplmfile;

die "Please provide --link-param-count" if !defined $linkparamcount;

-e $hyplmfile or die "Can't read $hyplmfile";
if (! -e "$emptyttablefile.binphr.idx") {
  die "The empty phrase table $emptyttablefile does not exist or is not binarized ($emptyttablefile.binphr.idx)";
}

my $ourweights_i = "0\n" x $linkparamcount;

my %aliases = qw(
dl      distortion-limit
);
my %fixvalues = (
  "distortion-limit" => 0,
  "link-param-count" => $linkparamcount,
  "inputtype" => 2,
  "max-phrase-length" => 600,
);

my %seen = ();

my $section = undef;
my $drop_old_ttables = 0;
my $drop_section_contents = 0;
my $wasweight_i = 0;
my $nr=0;
while (<>) {
  $nr++;
  if (/^\[([^]]+)\]/) {
    $section = $1;
    $section = $aliases{$section} if defined $aliases{$section};
    $drop_old_ttables = 0;
    $drop_section_contents = 0;
    print;
    if ($section eq "ttable-file") {
      $drop_old_ttables = 1;
      print "1 0 0 1 $emptyttablefile\n"; # add our ttable
    } elsif ($section eq "lmodel-file") {
      print "8 0 $hyplmorder $hyplmfile\n"; # add our lm
    } elsif ($section eq "weight-l") {
      print "$default_weight_l\n"; # add the weight for our lm
    } elsif ($section eq "weight-t") {
      print "0\n"; # weight for our fake ttable
      $drop_section_contents = 1;
    } elsif (defined $fixvalues{$section}) {
      $seen{$section} = 1;
      print "$fixvalues{$section}\n"; # use our value
      $drop_section_contents = 1;
    } elsif ($section eq "weight-i") {
      $wasweight_i = 1;
      print "$ourweights_i\n"; # initial weights
      $drop_section_contents = 1;
    }
    next;
  }
  if (/^\s*$/) {
    $drop_old_ttables = 0;
    $drop_section_contents = 0;
  }
  next if $drop_section_contents; # skip unused weights
  if ($drop_old_ttables) {
    chomp;
    my ($type, $srcf, $tgtf, $fname) = split / /, $_, 4;
    die "$nr:Unsuitable moses.ini, expects more input factors: $_"
      if $srcf ne "0";
    next; # drop old ttables
  }
  print;
}

print "\n";
foreach my $section (keys %fixvalues) {
  next if $seen{$section};
  print "[$section]\n$fixvalues{$section}\n\n";
}
print "[weight-i]\n$ourweights_i\n\n" if !$wasweight_i;


