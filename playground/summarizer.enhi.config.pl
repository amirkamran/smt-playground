# This is loaded by summarizer.pl to create beautiful tables of en->hi results

my $beautify = {
      "t0-0DEV" => "no-reord",
      "di.r0-0DEV" => "no-reord",
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
    "", "Just a delimiter line",
    "", 4, " ", " nic ", "nic", 0, $beautify, ],

  [
    "Morphology",
    "",
    # required
    "
    SRCtides
    en\\+lc
    hi\\+form
    ",
    # forbidden
    "
    DEVeilmt
    =OUTDATED=
    flm
    emille acl wiki dani
    t0-0At1-0
    ",
    1,
    # rows
    "
    t0-0\\.
    lcsuf([0-9]+)
    wc([0-9]+)
    tag
    u^hindo([2s]*)morsuf
    hitbsuf
    u^aff([bd]*)f
    cube
    ",
    # cols
    "
    or-bi-fe.r([01]-[01])
    LM([-0-9]*)
    ",
    # sort
    "hitbsuf",
    0, # verbose
    $beautify,
  ],

  [
    "Morphology with Daniel Pipes",
    "",
    # required
    "
    SRCtides
    en\\+lc
    hi\\+form
    dani
    or-bi-fe.r([01]-[01])
    ",
    # forbidden
    "
    dict
    DEVeilmt
    =OUTDATED=
    flm
    emille acl wiki
    t0-0At1-0
    0a272556
    ",
    1,
    # rows
    "
    LM(.*?)\\.t0
     ",
    # cols
    "
    t0-0\\.
    lcsuf([0-9]+)
    wc([0-9]+)
    tag
    u^hindo([2s]*)morsuf
    hitbsuf
    ",
    # sort
    "hitbsuf",
    0, # verbose
    $beautify,
  ],

  [
    "Morphology with Daniel Pipes and Filtered Dictionary",
    "",
    # required
    "
    SRCtides
    en\\+lc
    hi\\+form
    dani
    dict
    or-bi-fe.r([01]-[01])
    ",
    # forbidden
    "
    DEVeilmt
    =OUTDATED=
    flm
    emille acl wiki
    t0-0At1-0
    0a272556
    ",
    1,
    # rows
    "
    LM(.*?)\\.t0
     ",
    # cols
    "
    t0-0\\.
    lcsuf([0-9]+)
    wc([0-9]+)
    tag
    u^hindo([2s]*)morsuf
    hitbsuf
    ",
    # sort
    "hitbsuf",
    0, # verbose
    $beautify,
  ],

  [
    "Factored LMs",
    "",
    # required
    "
    SRCtides
    en\\+lc
    hi\\+form
    ",
    # forbidden
    "
    DEVeilmt
    =OUTDATED=
    emille acl wiki dani
    t0-0At1-0
    LM.-[57]
    ",
    1,
    # rows
    "
    or-bi-fe.r([01]-[01])
    t0-0\\.
    t0-([^.]+)
    u^lcsuf([0-9]+)
    u^wc([0-9]+)
    u^tag
    u^hindo([2s]*)morsuf
    u^hitbsuf
     ",
    # cols
    "
    flm sri
    tmplin lin([ft]) crap fftt
    ",
    # sort
    "flm sri",
    0, # verbose
    $beautify,
  ],

  [
    "Source vocabulary reduction",
    "",
    # required
    "
    SRCtides
    hi\\+form
    ",
    # forbidden
    "
    DEVeilmt
    =OUTDATED=
    emille acl wiki
    flm
    LM.-[57]
    LM0-3-tides.train\\+danielpipes-11
    ",
    1,
    # rows
    "
    or-bi-fe.r([01]-[01])
    t0-0\\.
    t0-([^.]+)
    lcsuf([0-9]+)
    wc([0-9]+)
    tag
    u^hindo([2s]*)morsuf
    danielpipes
    dictfilt
     ",
    # cols
    "
    en\\+lc
    en\\+enredvoc([0-9]+)
    ",
    # sort
    "en\\+lc",
    0, # verbose
    $beautify,
  ],

  [ "---------------------------------------",
    "", "Old unused tables",
    "", 4, " ", " nic ", "nic", 0, $beautify, ],
  [
    "Alignment",
    "",
    # required
    "
    icon-tides
    hi
    ALI
    ",
    # forbidden
    "
    ",
    1,
    # rows
    "
    (ALI[^.]+)
     ",
    # cols
    "
    SRCicon-([a-zA-Z]+)
    or-bi-fe.r([01]-[01])
    ",
    # sort
    "SRCicon-tides",
    0, # verbose
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
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
    $beautify,
  ],
);

# This is the main output:
\@scans;
