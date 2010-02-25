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
    "Single-step scenario, small parallel",
    "",
    # required
    "
    ",
    # forbidden
    "
    MID
    =OUTDATED= BLEU.opt
    09-
    wmt09czeng
    wmt09-news
    SRC[^A-Z]*.cs csX1
    TGT[^A]*\\+(plus|strip|)lemma
    ZMERTTER
    ",
    1,
    # rows
    "
    u^enNa(2?)
    t([0-9]+[a-][^.D]*)
    LM([-0-9]*-[^+]*)
    u^stcnums
    u^tag
    r0-([0-9]+)
    ",
    # cols
    "
    u^.
    092-eu
    ZMERT (SemPOS_BLEU|SemPOS|BLEU)
    tmt
    en([N4]*)\\+
    ",
    # sort
    "enN\\+",
    0, # verbose
    $beautify,
  ],
  [
    "Two-step",
    "",
    # required
    "
    MID|bsln|BEST|smallencs,bigLM
    ",
    # forbidden
    "
    =OUTDATED= BLEU.opt
    09-
    wmt09czeng
    wmt09-news
    ",
    1,
    # rows
    "
    u^enNa(2?)
    092-eu
    t([0-9]+[a-][^.D]*)
    lemma-csN?-lemma
    lcstem4-csN?-lcstem4
    LM([-0-9]*-[^+]*)
    ",
    # cols
    "
    SECphr([0-9]+)
    u^\\+(plus|strip|)lemma(2?)
    u^csX1
    u^.
    en([N4]*)\\+
    ",
    # sort
    "enN\\+",
    0, # verbose
    $beautify,
  ],
  [
    "Small Parallel",
    "",
    # required
    "
    ",
    # forbidden
    "
    =OUTDATED= BLEU.opt
    czeng09-
    czeng092-eu
    wmt09czeng
    wmt09-news
    pt[0-9]+to[0-9]+
    SRCczeng092-ne.cs
    TGT[^A]*lemma
    MID
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
    "enN\\+",
    0, # verbose
    $beautify,
  ],

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
    "enN\\+",
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
