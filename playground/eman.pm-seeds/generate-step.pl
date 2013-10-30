use warnings;
use strict;


sub bashstr {
my $what = shift;
my $res="#!/bin/bash
cp -r ../eman.pm-seeds/ eman.seeds-copy || exit

MYDIR=`pwd`
PERL5LIB=\$MYDIR/eman.seeds-copy:\$MYDIR/../eman.pm-seeds:\$PERL5LIB

[ -z \"\$INIT_ONLY\" ] || perl -e 'use Seeds::$what; my \$a=new Seeds::$what;\$a->_do_init;' || exit

[ -z \"\$INIT_ONLY\" ] || exit 0

perl -e 'use Seeds::$what; my \$a=new Seeds::$what;\$a->_do_prepare;' || exit

cat > eman.command << KONEC
#!/bin/bash

PERL5LIB=\$MYDIR/eman.seeds-copy:\$MYDIR/../eman.pm-seeds:\\\$PERL5LIB

perl -e 'use Seeds::$what; Seeds::$what->_do_run;' || eman fail .

KONEC
";
}

my $fn = $ARGV[0] or die "No input";
$fn =~ s/\.pm$//;
$fn =~ s/^Seeds\///;

if (!-e "Seeds/".$fn.".pm") {
    die "Seeds/$fn.pm does not exist";
}
if (!-d "../eman.seeds") {
    die "../eman.seeds does not exist";
}
open my $outf, ">", "../eman.seeds/".lc($fn)."-pm" or die "cannot open step file";
print $outf bashstr($fn);
close $outf;
system "chmod +x ../eman.seeds/".lc($fn)."-pm";
print "DONE\n"

