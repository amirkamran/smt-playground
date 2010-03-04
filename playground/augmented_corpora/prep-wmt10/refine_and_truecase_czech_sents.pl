#!/usr/bin/perl
# improve webcorpus sentences:

use strict;
use utf8;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my %known_ambig; # sentences starting with stc-ambiguous words dropped
my %known_lowercase; # sentences starting with lowercasable word lowercased
my %dict;
{ # Czech dict
my $dictf = "/home/bojar/diplomka/granty/emplus/wmt10/playground/augmented_corpora/all_cs_stc.gz";
print STDERR "Loading dictionary for cs: $dictf\n";
my $dicth = my_open($dictf);
my %forms;
while (<$dicth>) {
  chomp;
  my ($cnt, $word) = split /\t/;
  last if $cnt < 2; # require at least two occs
  next if $word !~ /^[[:alpha:]]+$/;
  my $lc = lc($word); # lowercasing
  if ($lc eq $word) {
    $forms{$lc}->{"lc"} = $cnt;
  } else {
    $forms{$lc}->{"oth"} += $cnt;
  }
  $dict{$lc} = 1;
}
close $dicth;
foreach my $lc (keys %forms) {
  my $lccnt = $forms{$lc}->{"lc"} || 0;
  my $othcnt = $forms{$lc}->{"oth"} || 0;
  my $totcnt = $lccnt+$othcnt;
  # print "$lccnt+$othcnt = $totcnt\n";
  if ($lccnt / $totcnt * 100 > 90) {
    $known_lowercase{$lc} = 1;
    # print "LC: $lc\n";
  } elsif ($lccnt / $totcnt * 100 > 40) {
    $known_ambig{$lc} = 1;
    # print "AMBIG: $lc\n";
  }
}
}

my $no = 0; # output sents
my $nr = 0;
my $sentbreaktag = "MySpEcIaLWord_MarkBrEaK";
while (<>) {
  $nr++;
  print STDERR "." if $nr % 10000 == 0;
  print STDERR "(in:$nr, out:$no)" if $nr % 100000 == 0;
  print STDERR "\n" if $nr % 1000000 == 0;
  chomp;
  s/([.!?:] [“‘]* *)(["„‚]* * [[:upper:]])/$1 $sentbreaktag $2/go;
  my @sents = split /$sentbreaktag/o;
  foreach my $s (@sents) {
    $s =~ s/^ +//;
    $s =~ s/ +$//;

    # avoid all-caps sents
    next if $s !~ /[[:lower:]]/;

    # avoid sents. ending with abbrev
    next if $s =~ /( |^)(a|A|Acad|angl|ap|apod|arch|Arch|Ass|atd|B|Bc|C|č|Č|čl|Čl|ČL|CSc|D|diag|Diag|DIAG|Dis|DiS|doc|Doc|DOC|dr|Dr|DR|DrSc|E|el|F|fr|Fr|franc|G|hl|Hl|HL|I|inf|ing|Ing|ING|J|JUDr|JUDR|K|kal|Kal|KAL|kap|Kap|KAP|Kč|kn|l|L|M|mat|max|MBA|MD|Mgr|mil|min|mj|Mj|MJ|mld|MUDr|MUDR|MVDr|N|nám|Nám|NÁM|např|Např|NAPŘ|násl|Násl|NÁSL|o|O|obr|Obr|OBR|odst|Odst|ODST|ops|p|P|Ph|PharmDr|PhD|PhDr|PHDR|pozn|přibl|Přibl|PŘIBL|prof|Prof|PROF|prom|Prom|PROM|Q|r|R|ř|Ř|Řehoře|resp|Resp|RESP|RNDr|RNDR|s|S|Š|Sb|Sc|Šebestiána|Šimona|spol|sro|st|Štěpána|stol|str|Str|STR|sv|Sv|Syrského|T|Taegna|Taegoona|tel|Tel|TEL|Terezie|ThDr|THDR|Timoteje|tis|Tita|tj|Tj|TJ|Tomáše|Turibia|tzn|tzv|Tzv|TZV|U|Uherské|Uherského|ul|Ul|UL|Umučení|Úř|V|Václava|Vavřince|vč|Vč|VČ|Velikého|Vercelli|věst|Vianneye|Vincence|Víta|Vojtěcha|W|Wolfganga|X|Xaverského|Y|Z|Ž|Zdislavy|zejm|Zejm|ZEJM|Zhao|Zikmunda|Zlatoústého|zvl|Zvl|ZVL) .$/;

    # avoid sents not starting with an uppercased word
    # print "CONSIDERING: ".$s."\n";
    next if $s !~ /^([[:punct:] ]*)([[:upper:]][[:alpha:]]*)( )/;
    my $prefix = $1;
    my $word1 = $2;
    my $suffix = $3;
    my $lcword1 = lc($word1);
    # ...and handle the uppercasing
    if ($known_ambig{$lcword1}) {
      # print STDERR "AMBIG $lcword1 $word1\n";
      next;
    }
    if ($known_lowercase{$lcword1}) {
      $s =~ s/^$prefix$word1$suffix/$prefix$lcword1$suffix/;
    }

    my $totwords = 0;
    my $okwords = 0;
    while ($s =~ /[[:alpha:]]+/g) {
      my $word = $&;
      $totwords ++;
      $okwords ++ if $dict{lc($word)};
    }
    next if $okwords < 6;
    next if $okwords / $totwords * 100 < 80; # require 80 % valid words
    print $s."\n";
    $no++;
  }
}

print STDERR "Done.\n";
print STDERR "Insents: $nr\n";
print STDERR "Outsents: $no\n";

sub my_open {
  my $f = shift;
  if ($f eq "-") {
    binmode(STDIN, ":utf8");
    return *STDIN;
  }

  die "Not found: $f" if ! -e $f;

  my $opn;
  my $hdl;
  my $ft = `file '$f'`;
  # file might not recognize some files!
  if ($f =~ /\.gz$/ || $ft =~ /gzip compressed data/) {
    $opn = "zcat '$f' |";
  } elsif ($f =~ /\.bz2$/ || $ft =~ /bzip2 compressed data/) {
    $opn = "bzcat '$f' |";
  } else {
    $opn = "$f";
  }
  open $hdl, $opn or die "Can't open '$opn': $!";
  binmode $hdl, ":utf8";
  return $hdl;
}

