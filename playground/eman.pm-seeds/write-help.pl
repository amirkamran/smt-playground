use warnings;
use strict;

my $fn = $ARGV[0] or die "No input";

$fn =~ s/\.pm$//;
$fn =~ s/^Seeds\///;

if (!-e "Seeds/".$fn.".pm") {
    die "Seeds/$fn.pm does not exist";
}
$fn = "Seeds::$fn";
use Module::Load;
load $fn;
my $cl = new $fn;
$cl->write_help;
