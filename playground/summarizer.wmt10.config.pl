# This is loaded by summarizer.pl to create beautiful tables of en->hi results

my $beautify = {
      "LM0[^L]*sri" => "LM0sri",
      "LM1[^L]*sri" => "LM1sri",
    };

my @scans = (
  [ "---------------------------------------",
    "", "Just a delimiter line",
    "", 4, " ", " nic ", "nic", 0, $beautify, ],

  [
    "Normalization",
    "",
    # required
    "
    ",
    # forbidden
    "
    =OUTDATED= BLEU.opt
    czeng09-eu
    czeng09-fi
    wmt09czeng
    wmt09-news
    pt[0-9]+to[0-9]+
    tag
    ",
    1,
    # rows
    "
    t0-0\\.
    lemma-csN?-lemma
    lcstem4-csN?-lcstem4
    LM([-0-9]*)
    gdf(a?)
    ",
    # cols
    "
    en([N4]*)\\+
    csN
    ",
    # sort
    "hitbsuf",
    0, # verbose
    $beautify,
  ],
  [
    "Sigfilter",
    "",
    # required
    "
    ",
    # forbidden
    "
    =OUTDATED= BLEU.opt
    wmt09czeng
    wmt09-news
    ",
    1,
    # rows
    "
    t0-0\\.
    lemma-csN?-lemma
    lcstem4-csN?-lcstem4
    LM([-0-9]*)
    gdf(a?)
    en([N4]*)\\+
    csN
    t([0-9]+[a-][^.]*)
    pt([0-9]+to[0-9]+)
    GEN RBpenal
    c^-ne
    c^-eu
    c^-fi
    c^-su
    c^-te
    c^-we
    ",
    # cols
    "
    SIG([a+e0-9.N]*)
    ",
    # sort
    "hitbsuf",
    -1, # verbose
    $beautify,
  ],
);

# This is the main output:
\@scans;
