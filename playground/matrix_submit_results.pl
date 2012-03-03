#!/usr/bin/env perl
# Submits WMT 2012 test results to http://matrix.statmt.org/.
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
sub usage
{
    print STDERR ("Usage: matrix_submit_results.pl <options> <filepath>\n");
    print STDERR ("Options:\n");
    print STDERR ("       -usr: user name for matrix.statmt.org\n");
    print STDERR ("       -psw: password\n");
    print STDERR ("       -src: source language (cs|de|en|es|fr)\n");
    print STDERR ("       -tgt: target language (cs|de|en|es|fr)\n");
    print STDERR ("       -notes: notes about this system run\n");
}
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Carp;
use Getopt::Long;
use dzsys;
use htmlform;

GetOptions
(
    'usr=s' => \$konfig{uzivatel},
    'psw=s' => \$konfig{heslo},
    'src=s' => \$konfig{src},
    'tgt=s' => \$konfig{tgt},
    'notes=s' => \$konfig{notes}
);
if(!$konfig{uzivatel} || !$konfig{heslo})
{
    usage();
    confess("Unknown user or password");
}

# Create web client.
my $ua = htmlform::vytvorit_klienta();
# Download the login page.
print STDERR ("Log in...\n");
my $url = 'http://matrix.statmt.org/account/login';
my $response = $ua->get($url);
if(!$response->is_success())
{
    print STDERR ("Cannot log in.\n");
    print STDERR ("URL = $url\n");
    confess;
}
my $html = $response->content();
my $formular = htmlform::precist_formular($html);
htmlform::nastavit_hodnotu($formular, 'login', $konfig{uzivatel});
htmlform::nastavit_hodnotu($formular, 'password', $konfig{heslo});
my $podvoj = htmlform::ziskat_pole_dvojic($formular, 'Log in');
$response = htmlform::post($ua, $url, $podvoj, 'application/x-www-form-urlencoded');
# Submission starts here.
# Note that the language pair codes are probably specific to newstest2012.
# More importantly, note that the system ids known to this script all belong to Dan.
my %ids = # testset id, system id
(
    'de-en' => [1692, 1792],
    'de-es' => [1693],
    'de-fr' => [1694],
    'de-cs' => [1695, 1791],
    'en-de' => [1696, 1794],
    'en-es' => [1697, 1795],
    'en-fr' => [1698, 1796],
    'en-cs' => [1699, 1793],
    'es-de' => [1700],
    'es-en' => [1701, 1798],
    'es-fr' => [1702],
    'es-cs' => [1703, 1797],
    'fr-de' => [1704],
    'fr-en' => [1705, 1800],
    'fr-es' => [1706],
    'fr-cs' => [1707, 1799],
    'cs-de' => [1708, 1787],
    'cs-en' => [1709, 1788],
    'cs-es' => [1710, 1789],
    'cs-fr' => [1711, 1790]
);
my $pair = "$konfig{src}-$konfig{tgt}";
confess("Unknown language pair $pair") unless($ids{$pair} && $ids{$pair}[1]);
if(0)
{
    $response = $ua->get('http://matrix.statmt.org/submission');
    $html = $response->content();
    $formular = htmlform::precist_formular($html);
    htmlform::nastavit_hodnotu($formular, 'test_set[id]', 16); # newstest2012
    htmlform::nastavit_hodnotu($formular, 'test_setup[16]', $ids{$pair}[0]);
    htmlform::nastavit_hodnotu($formular, 'system[id]', $ids{$pair}[1]);
    $podvoj = htmlform::ziskat_pole_dvojic($formular, 'Continue');
    $response = htmlform::post($ua, 'http://matrix.statmt.org/submission/create', $podvoj, 'application/x-www-form-urlencoded');
    $html = $response->content();
    $formular = htmlform::precist_formular($html);
    htmlform::nastavit_hodnotu($formular, 'run[test_setup_id]', $ids{$pair}[0]);
    htmlform::nastavit_hodnotu($formular, 'run[system_id]', $ids{$pair}[1]);
    htmlform::nastavit_hodnotu($formular, 'run[notes]', $konfig{notes});
    my $filerecord = $formular->{hash}{'run[file_sgm]'};
    $filerecord->{filename} = $ARGV[0];
    $filerecord->{filetype} = 'text/xml';
    $filerecord->{value} = dzsys::safeticks("cat $ARGV[0]");
}
%formular =
(
    'action' => 'http://matrix.statmt.org/submission/create',
    'method' => 'post',
    'enctype' => 'multipart/form-data',
    'array' =>
    [
        {'name' => 'run[test_setup_id]', 'value' => $ids{$pair}[0]},
        {'name' => 'run[system_id]', 'value' => $ids{$pair}[1]},
        {'name' => 'run[notes]', 'value' => $konfig{notes}},
        {'name' => 'run[file_sgm]', 'type' => 'file', 'filename' => $ARGV[0], 'filetype' => 'text/xml',
                   'value' => dzsys::safeticks("cat $ARGV[0]")},
        {'type' => 'submit', 'name' => 'commit', 'value' => 'Save Run'}
    ]
);
foreach my $field (@{$formular{array}})
{
    $formular{hash}{$field->{name}} = $field;
}
$podvoj = htmlform::ziskat_pole_dvojic(\%formular, 'Save Run');
$response = htmlform::post($ua, 'http://matrix.statmt.org/submission/create', $podvoj, 'application/x-www-form-urlencoded');
