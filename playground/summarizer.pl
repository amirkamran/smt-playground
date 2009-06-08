#!/usr/bin/perl -I/home/ws06/obojar/diplomka/smt-quickrun/pbt_aachen -I/home/obo/diplomka/smt-quickrun/pbt_aachen/ -I/home/bojar/diplomka/smt-quickrun/pbt_aachen/

use strict;
use Summarizer;

my $data = Summarizer::load(*STDIN);
    
my $beautify = {
      "2051" => "out-of-domain-D",
      "964" => "domain-D",
      "LM.*LM" => "two-LMs",
      "lc\\+2" => "tag",
      "TGTlc[^.]*\\+2" => "tag",
    };

my $valembeautify = {
      "t0-0DEV" => "no-reord",
      "di.r0-0DEV" => "no-reord",
      "1130" => "FIXED",
      "or-bi-fe.r0-0" => "reord-using-hi-forms",
      "or-bi-fe.r0-1" => "reord-using-wcX/dzsuf",
      "or-bi-fe.r1-1" => "reord-using-entags-hiwcX/dzsuf",
      "hi\\." => "baseline",
      "\\+en\\+" => "baseline",
      "\\+enP\\+" => "penntok",
      "\\+enR\\+" => "penntok+dzReord",
    };

my @scans = (
  [ "---------------------------------------",
    "", "Just a delimiter line, below are tables for experimenting with valem",
    "", 4, " ", " nic ", "nic", 0, $valembeautify, ],
  [
    "Alignment",
    "",
    # required
    "
    hi
    ALI
    ",
    # forbidden
    "
    enR
    tides web eiti allFIX
    wc dzsuf
    devnormal
    DEVicon-tides
    ALIicon-all
    devnorm
    ",
    1,
    # rows
    "
    (ALI[^.]+)
     ",
    # cols
    "
    web
    tides
    SRCicon-([a-zA-Z]+)
    or-bi-fe.r([01]-[01])
    ",
    # sort
    "SRCicon-eilmt",
    0, # verbose
    $valembeautify,
  ],
  [
    "Parallel corpus size-simple-mtevalBLEU",
    "",
    # required
    "
    hi
    ALIlcstem4-lcstem4
    ",
    # forbidden
    "
    enR
    tides web
    wc dzsuf
    devnormal
    DEVicon-tides
    ALIicon-all
    ",
    3,
    # rows
    "
    web
    tides
    SRCicon-([a-zA-Z]+)
     ",
    # cols
    "
    or-bi-fe.r([01]-[01])
    t0-0DEV
    ",
    # sort
    "no-reord",
    0, # verbose
    $valembeautify,
  ],
  [
    "Parallel corpus size-simple",
    "",
    # required
    "
    hi
    ALIlcstem4-lcstem4
    ",
    # forbidden
    "
    enR
    tides web
    wc dzsuf
    devnormal
    DEVicon-tides
    ALIicon-all
    ",
    1,
    # rows
    "
    web
    tides
    SRCicon-([a-zA-Z]+)
     ",
    # cols
    "
    or-bi-fe.r([01]-[01])
    t0-0DEV
    ",
    # sort
    "no-reord",
    0, # verbose
    $valembeautify,
  ],
  [
    "LM corpus size-simple-mteval",
    "",
    # required
    "
    ALIlcstem4-lcstem4
    DEVicon-eilmt
    ",
    # forbidden
    "
    enR
    tides
    eiti
    wc dzsuf
    devnormal
    DEVicon-tides
    SRCicon-all\\+
    ",
    3,
    # rows
    "
    SRCicon-([a-zA-Z0-9]+)
    web
     ",
    # cols
    "
    or-bi-fe.r([01]-[01])
    t0-0DEV di.r0-0DEV
    ",
    # sort
    "reord-using-hi-forms",
    0, # verbose
    $valembeautify,
  ],
  [
    "LM corpus size-simple",
    "",
    # required
    "
    ALIlcstem4-lcstem4
    DEVicon-eilmt
    ",
    # forbidden
    "
    enR
    tides
    eiti
    wc dzsuf
    devnormal
    DEVicon-tides
    SRCicon-all\\+
    ",
    1,
    # rows
    "
    SRCicon-([a-zA-Z0-9]+)
    web
     ",
    # cols
    "
    or-bi-fe.r([01]-[01])
    t0-0DEV di.r0-0DEV
    ",
    # sort
    "reord-using-hi-forms",
    0, # verbose
    $valembeautify,
  ],
  [
    "Parallel corpus size",
    "",
    # required
    "
    hi
    ",
    # forbidden
    "
    wc dzsuf
    devnormal
    DEVicon-tides
    ",
    1,
    # rows
    "
    (ALI[^.]+)
    LM([0-9]+-[0-9]+)
    t0-0\\+t1-0
    t0-0\\.
    web
    tides
    or-bi-fe.r([01]-[01])
     ",
    # cols
    "
    SRCicon-([a-zA-Z]+)
    ",
    # sort
    "SRCicon-eilmt",
    0, # verbose
    $valembeautify,
  ],
  [
    "Normalization",
    "",
    # required
    "
    hi
    ",
    # forbidden
    "
    wc dzsuf
    DEVicon-tides
    ",
    1,
    # rows
    "
    SRCicon-([a-zA-Z]+)
    (ALI[^.]+)
    LM([0-9]+-[0-9]+)
    web
    tides
    t0-0\\+t1-0
    t0-0\\.
    or-bi-fe.r([01]-[01])
     ",
    # cols
    "
    (hi\\.|devnormal2?)
    ",
    # sort
    "hi.",
    0, # verbose
    $valembeautify,
  ],
  [
    "Reorderings",
    "",
    # required
    "
    SRCicon-eilmt
    lcstem4-lcstem4
    ",
    # forbidden
    "
    devnormal
    web tides
    Exiting
    ",
    1,
    # rows
    "
    (ALI[^.]+)
    LM([0-9]+-[0-9]+)
    or-bi-fe.r([01]-[01])
     ",
    # cols
    "
    hi\\.
    dzsuf
    wc10
    wc50
    1130
    ",
    # sort
    "SRCicon-eilmt",
    0, # verbose
    $valembeautify,
  ],
  [
    "Reorderings - for paper",
    "",
    # required
    "
    lcstem4-lcstem4
    ",
    # forbidden
    "
    wc[15]0.*112[89]
    LM1-[357]
    devnormal
    web 
    Exiting
    wc10 wc50
    all eiti
    LM0-3-icon-eilmtLM0-3-icon-tides
    ",
    1,
    # rows
    "
    \\+en([RP]?)\\+
    or-bi-fe.r([01]-[01])
    dzsuf
     ",
    # cols
    "
    DEVicon-tides
    DEVicon-eilmt
    ",
    # sort
    "DEVicon-eilmt",
    0, # verbose
    undef,
  ],
  [
    "Reorderings - simplified view, eilmt",
    "",
    # required
    "
    SRCicon-eilmt
    lcstem4-lcstem4
    ",
    # forbidden
    "
    wc[15]0.*112[89]
    LM1-[357]
    devnormal
    web tides
    Exiting
    ",
    1,
    # rows
    "
    \\+en([RP]?)\\+
    or-bi-fe.r([01]-[01])
     ",
    # cols
    "
    hi\\.
    dzsuf
    wc10
    wc50
    ",
    # sort
    "SRCicon-eilmt",
    0, # verbose
    $valembeautify,
  ],
  [
    "Reorderings - tides",
    "",
    # required
    "
    SRCicon-tides
    lcstem4-lcstem4
    ",
    # forbidden
    "
    web
    eiti
    ",
    1,
    # rows
    "
    \\+en([RP]?)\\+
    or-bi-fe.r([01]-[01])
     ",
    # cols
    "
    hi\\.
    dzsuf
    wc10
    wc50
    ",
    # sort
    "baseline",
    0, # verbose
    $valembeautify,
  ],
  [
    "Reorderings - tides, trained on eiti",
    "",
    # required
    "
    SRCicon-eiti
    lcstem4-lcstem4
    DEVicon-tides
    ",
    # forbidden
    "
    web
    ",
    1,
    # rows
    "
    (ALI[^.]+)
    or-bi-fe.r([01]-[01])
     ",
    # cols
    "
    hi\\.
    dzsuf
    wc10
    wc50
    ",
    # sort
    "baseline",
    0, # verbose
    $valembeautify,
  ],
);


# my @scans = @wmtscans;

foreach my $scan (@scans) {
  my ($title, $subtitle, $req, $forb, $col, $rows, $cols, $sortcol, $verbose, $tokenmap)
    = @$scan;
  Summarizer::newscan(
    {
      title=>$title,
      subtitle=>$subtitle,
      reqtoks=>$req,
      forbtoks=>$forb,
      col=>$col,
      rowtoks=>$rows,
      coltoks=>$cols,
      sortcol=>$sortcol,
      verbose=>$verbose,
      tokenmap=>$tokenmap,
    },
    $data);
}
