# This is loaded by summarizer.pl to create beautiful tables of en->hi results
use utf8;

my $beautify = {
      "LM0[^L]*sri" => "LM0sri",
      "LM1[^L]*sri" => "LM1sri",
    };

my @scans = (
  [ "---------------------------------------",
    "", "Just a delimiter line",
    "", 4, " ", " nic ", "nic", 0, $beautify, ],
  [
    "To English",
    "",
    # required
    "
    092
    SRC[^A-MO-Z]*cs[^A-MO-Z]*TGT[^A-MO-Z]*en[^A-MO-Z]*ALI
    ",
    # forbidden
    "
    =FAILED=
    MID
    TESTwmt10
    Nm\\+lemma
    7.64±0.32
    ",
    1,
    # rows
    "
    t([0-9]+[a-][^.D]*)
    LM([-0-9]*-[^+]*)
    u^stcnums
    u^tag
    r0-([0-9]+)
    N([0-9]+)
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
    "Two-step SMALL",
    "",
    # required
    # MID|bsln|BEST|smallencs,bigLM|201004
    "
    enNa2
    TGT\\+csN[am]\\+stc
    ",
    # forbidden
    "
    g0-1 t0a1 split ZMERT
    webcoll
    BLEU.opt
    09-
    wmt09czeng wmt09mono
    wmt09-news
    092-na
    TESTwmt102
    092-eu
    ",
    "BLEU.opt,SemPOS.opt",
    # rows
    "
    u^enNa(2?)
    u^t([0-9]+[a-][^.D]*)
    lemma-csN?-lemma
    lcstem4-csN?-lcstem4
    LM([-0-9]*-[^+]*)
    N([0-9]+)
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
    "\\+pluslemma2 .",
    0, # verbose
    $beautify,
    " / ",
  ],
  [
    "Two-step LARGE",
    "",
    # required
    # MID|bsln|BEST|smallencs,bigLM|201004
    "
    enNa2
    TGT\\+csN[am]\\+stc
    092-eu
    ",
    # forbidden
    "
    g0-1 t0a1 split ZMERT
    webcoll
    =OUTDATED= BLEU.opt
    09-
    wmt09czeng wmt09mono
    wmt09-news
    092-na
    TESTwmt102
    ",
    1,
    # rows
    "
    u^enNa(2?)
    t([0-9]+[a-][^.D]*)
    lemma-csN?-lemma
    lcstem4-csN?-lcstem4
    LM([-0-9]*-[^+]*)
    N([0-9]+)
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
    "\\+pluslemma2 .",
    0, # verbose
    $beautify,
    " / ",
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
    "SEMPOS SMALL",
    "",
    # required
    "
    ZMERT
    ",
    # forbidden
    "
    092-eu wmt10mono2
    BLEU.opt
    =FAILED=
    ",
    "BLEU.opt,SemPOS.opt",  # values
    # rows
    "
    (SemPOS_BLEU|SemPOStmt|SemPOS|BLEU)
    WEIGHTS([0-9:]*)
    ",
    # t([0-9]+[a-][^.D]*)
    # cols
    "
    \\+enNa(2?)
    LM([-0-9]*)
    ",
    # sort
    "enN\\+",
    0, # verbose
    $beautify,
    " / ", # collect-delimiter
  ],
  [
    "SEMPOS LARGE",
    "",
    # required
    "
    ZMERT
    092-eu
    ",
    # forbidden
    "
    BLEU.opt
    =FAILED=
    ",
    "BLEU.opt,SemPOS.opt",  # values
    # rows
    "
    (SemPOS_BLEU|SemPOStmt|SemPOS|BLEU)
    WEIGHTS([0-9:]*)
    ",
    # t([0-9]+[a-][^.D]*)
    # cols
    "
    \\+enNa(2?)
    LM([-0-9]*)
    ",
    # sort
    "enN\\+",
    0, # verbose
    $beautify,
    " / ", # collect-delimiter
  ],

#   [
#     "Normalization",
#     "",
#     # required
#     "
#     ",
#     # forbidden
#     "
#     =OUTDATED= BLEU.opt
#     czeng09-eu
#     czeng09-fi
#     wmt09czeng
#     wmt09-news
#     pt[0-9]+to[0-9]+
#     tag
#     ",
#     1,
#     # rows
#     "
#     t0-0\\.
#     lemma-csN?-lemma
#     lcstem4-csN?-lcstem4
#     LM([-0-9]*)
#     gdf(a?)
#     ",
#     # cols
#     "
#     en([N4]*)\\+
#     csN
#     ",
#     # sort
#     "enN\\+",
#     0, # verbose
#     $beautify,
#   ],
#   [
#     "Sigfilter",
#     "",
#     # required
#     "
#     ",
#     # forbidden
#     "
#     =OUTDATED= BLEU.opt
#     wmt09czeng
#     wmt09-news
#     ",
#     1,
#     # rows
#     "
#     t0-0\\.
#     lemma-csN?-lemma
#     lcstem4-csN?-lcstem4
#     LM([-0-9]*)
#     gdf(a?)
#     en([N4]*)\\+
#     csN
#     t([0-9]+[a-][^.]*)
#     pt([0-9]+to[0-9]+)
#     GEN RBpenal
#     c^-ne
#     c^-eu
#     c^-fi
#     c^-su
#     c^-te
#     c^-we
#     ",
#     # cols
#     "
#     SIG([a+e0-9.N]*)
#     ",
#     # sort
#     "hitbsuf",
#     -1, # verbose
#     $beautify,
#   ],
);

# This is the main output:
\@scans;
