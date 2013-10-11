use warnings;
use strict;


sub bashstr {
my $what = shift;
my $res="#!/bin/bash
cp ../eman.pm-seeds/$what.pm .

MYDIR=`pwd`
PERL5LIB=\$MYDIR:\$MYDIR/../eman.pm-seeds:\$PERL5LIB

[ -z \"\$INIT_ONLY\" ] || perl -e 'use $what; my \$a=new $what;\$a->_do_init;' || exit

[ -z \"\$INIT_ONLY\" ] || exit 0

perl -e 'use $what; my \$a=new $what;\$a->_do_prepare;' || exit

cat > eman.command << KONEC
#!/bin/bash

PERL5LIB=\$MYDIR:\$MYDIR/../eman.pm-seeds:\\\$PERL5LIB

perl -e 'use $what; $what->_do_run;' || exit

KONEC
";
}

my $fn = $ARGV[0] or die "No input";
if (!-e $fn.".pm") {
    die "$fn.pm does not exist";
}
if (!-d "../eman.seeds") {
    die "../eman.seeds does not exist";
}
open my $outf, ">", "../eman.seeds/".lc($fn)."-pm" or die "cannot open step file";
print $outf bashstr($fn);
close $outf;
system "chmod +x ../eman.seeds/".lc($fn)."-pm";
print "DONE\n"

