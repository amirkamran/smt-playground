#!/usr/bin/env perl
# Creates system records at http://matrix.statmt.org/.
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
sub usage
{
    print STDERR ("Usage: matrix_create_systems.pl <options>\n");
    print STDERR ("Options:\n");
    print STDERR ("       -usr: user name for matrix.statmt.org\n");
    print STDERR ("       -psw: password\n");
}
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Carp;
use Getopt::Long;
use htmlform;

GetOptions
(
    'usr=s'  => \$konfig{uzivatel},
    'psw=s'  => \$konfig{heslo},
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
foreach my $src qw(cs de en es fr)
{
    foreach my $tgt qw(cs de en es fr)
    {
        if($src ne $tgt && ($src =~ m/^(cs|en)$/ || $tgt =~ m/^(cs|en)$/))
        {
            print STDERR ("Creating $src-$tgt...\n");
            $url = 'http://matrix.statmt.org/systems/new';
            $response = $ua->get($url);
            if(!$response->is_success())
            {
                confess("Cannot download the new system form");
            }
            $html = $response->content();
            $formular = htmlform::precist_formular($html);
            htmlform::nastavit_hodnotu($formular, 'system[name]', 'uk-dan-moses');
            htmlform::nastavit_hodnotu($formular, 'system[software]', 'Moses');
            htmlform::nastavit_hodnotu($formular, 'system[source_lang]', uc($src));
            htmlform::nastavit_hodnotu($formular, 'system[target_lang]', uc($tgt));
            htmlform::nastavit_hodnotu($formular, 'system[citation]', 'Koehn et al., 2007');
            htmlform::nastavit_hodnotu($formular, 'system[web_site]', 'http://www.statmt.org/moses/');
            $podvoj = htmlform::ziskat_pole_dvojic($formular, 'Create');
            $response = htmlform::post($ua, 'http://matrix.statmt.org/systems/create', $podvoj, 'application/x-www-form-urlencoded');
        }
    }
}
