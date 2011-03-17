#!/usr/bin/perl
# Converts 'bilanguage format', i.e.:
#
# barack|barack obama|obama se|se stane|stane čtvrtým|čtvrtým americkým|americkým prezidentem|prezidentem na|, $|jak $|dostat nobelovu|nobelovu cenu|cenu míru|míru
# barack|barack obama|obama se|se stane|stane čtvrtým|čtvrtým americkým|americkým prezidentem|prezidentem na|, $|jak $|dostat nobelovu|nobelovu cenu|cenu míru|míru
# barack|barack obama|obama se|se stane|stane čtvrtým|čtvrtým americkým|americkým prezidentem|prezidentem ,|, $|jak $|dostat obdrží|nobelovu cenu|cenu míru|$ nobela|míru
#
# to the lattice of confusion networks.
#
# Each arc is equipped with many weights:
#   apriori-weight ... apriori weights of systems (e.g. based on outside scores)
#   voting         ... the percentage of systems voting for this particular
#                      word at the given conf. net column
#   sentence-level ... one for each system, indicating whether we are using
#                      the system as the skeleton, collected incrementally
#                      along the sentence
#   arc-level      ... one for each system, indicating how many output words
#                      were produced by the given system (incl. eps)
#                      ... these add up to voting-weight, so you should use
#                          either arc-level or voting
#   primary-arcs   ... how many output arcs are produced by the primary system
#   primary-words  ... how many output words (i.e. arcs excl. epsilon) are
#                      produced by the primary system
#
# Ondrej Bojar, bojar@ufal.mff.cuni.cz

use strict;
use Getopt::Long;

my $featset = "apriori,voting,sentlevel,arclevel,primarcs,primwords";
my $verbose = 0;
my $tokenize_at_underscore = 0; # accept multi_token bilang input
my $eps = "*EPS*"; # Moses notation for epsilon
my $apriori_weights = undef; # each primary system can be given a weight based
                             # on it's performance on a separate set
my $mangle_indicators = "zero-one";
    #    zero-one ...> default
    #    one-zero ...> 
    #                 ... should just lead to the weight of the indicator to be
    #                 optimized to its negative value but normalization in
    #                 optimizers impacts this
    #    minus-plus ...> for centered values
my $weight_domain = "prob";
    # what should the target numbers as weights mean at each arc:
    #    prob    ...> should be probabilities, indicators are exp(0)/exp(1)
    #    log     ...> should be log(p), indicators are just 0/1
    #    neglog  ...> should be -log(p), indicators are just -0/-1
GetOptions(
  "featset|feature-set=s" => \$featset,
  "apriori-weights=s" => \$apriori_weights, # provide as probs, not log(p)
  "mangle-indicators=s" => \$mangle_indicators,
  "weight-domain=s" => \$weight_domain,
  "tokenize-at-underscore" => \$tokenize_at_underscore,
    # and also unescape underscore
) or exit 1;

my $nSystems = shift;
die "usage: $0 num-of-Systems < bilang > att" if !defined $nSystems;

my @wished_feats = split /,/, $featset;

my @apriori_weights;
if (defined $apriori_weights) {
  @apriori_weights = split /,/, $apriori_weights;
  die "Expected $nSystems apriori weights, got " .scalar($apriori_weights).": $apriori_weights" 
    if scalar(@apriori_weights) != $nSystems;
} else {
  print STDERR "Using equal apriori weights.\n";
  @apriori_weights = map { 1/$nSystems } (1..$nSystems);
}

my $ind_mangler;
my $prob_mangler;
my $cumul_mangler;
if ($weight_domain eq "prob") {
  # required by moses, moses always applies log to input
  # not suitable for tropical seminiring, maximizes probability
  $prob_mangler = sub { return shift };
  $cumul_mangler = sub { return shift };
  if ($mangle_indicators eq "zero-one") {
    $ind_mangler = sub { my $v = shift; return exp($v) };
  } elsif ($mangle_indicators eq "one-zero") {
    $ind_mangler = sub { my $v = shift; return exp($v?0:1) };
  } elsif ($mangle_indicators eq "minus-plus") {
    $ind_mangler = sub { my $v = shift; return exp($v?1:-1) };
  } else {
    die "Bad --mangle-indicators: $mangle_indicators";
  }
} elsif ($weight_domain eq "log") {
  # not suitable for tropical semiring, minimizes probability
  $prob_mangler = sub { my $v = shift; return log($v) };
  $cumul_mangler = sub { return shift };
  if ($mangle_indicators eq "zero-one") {
    $ind_mangler = sub { my $v = shift; return $v?1:0 };
  } elsif ($mangle_indicators eq "one-zero") {
    $ind_mangler = sub { my $v = shift; return $v?0:1 };
  } elsif ($mangle_indicators eq "minus-plus") {
    $ind_mangler = sub { my $v = shift; return $v?1:-1 };
  } else {
    die "Bad --mangle-indicators: $mangle_indicators";
  }
} elsif ($weight_domain eq "neglog") {
  # suitable for tropical semiring if indicators not mangled
  $prob_mangler = sub { my $v = shift; return -log($v) };
  $cumul_mangler = sub { my $v = shift; return -$v; };
  if ($mangle_indicators eq "zero-one") {
    $ind_mangler = sub { my $v = shift; return -($v?1:0) };
  } elsif ($mangle_indicators eq "one-zero") {
    $ind_mangler = sub { my $v = shift; return -($v?0:1) };
  } elsif ($mangle_indicators eq "minus-plus") {
    $ind_mangler = sub { my $v = shift; return -($v?1:-1) };
  } else {
    die "Bad --mangle-indicators: $mangle_indicators";
  }
} else {
  die "Bad --weight-domain: $weight_domain";
}

my $nr = 0;
while (!eof(STDIN)) {
  my @rover = (); # the array of all confusion networks
  foreach my $primary (0..$nSystems-1) {
    # build a confusion network
    my $cn = undef;
    # $cn->[column]->{sysid} = $token
    #    ... at which position which system produced which token
    my $firstrun = 1;
    foreach my $secondary (0..$nSystems-1) {
      next if $secondary == $primary;
      # print STDERR "Inserting $secondary to $primary.\n";
      my $line = <>;
      $nr++;
      die "$nr:Unexpected end of input" if !defined $line;
      chomp $line;
      die "$nr:Reserved token $eps in input!" if $line =~ /\Q$eps/;
      my @toks = split / /, $line;
      my $column = 0;
      foreach my $tokpair (split / /, $line) {
        my ($sectok, $primtok) = split /\|/, $tokpair;
        # relabel epsilons
        $sectok = $eps if $sectok eq '$';
        $primtok = $eps if $primtok eq '$';
        if ($firstrun) {
          # just insert both the primary and the secondary to the cn
          push @$cn, { $primary => $primtok, $secondary => $sectok };
        } else {
          # merge the current line with the cn
          while (1) {
            # walk the cn until we find the right column
            # print STDERR "Walk: at $column\n";
            if (!defined $cn->[$column]) {
              die "Bug 1" if $primtok ne $eps;
              # we're beyond the cn, add extra column
              push @$cn, { $primary => $eps, $secondary => $sectok };
              last;
            }
            my $colval = $cn->[$column]->{$primary};
            # print STDERR "  colval: $colval, prim: $primtok, sec: $sectok\n";
            if ($colval eq $primtok) {
              # this is the right column
              $cn->[$column]->{$secondary} = $sectok;
              $column++;
              last;
            }
            if ($colval eq $eps) {
              # need to step further, the cn has epsilon here
              $column++;
              next;
            }
            if ($primtok eq $eps) {
              # need to insert a new column here
              splice(@$cn, $column, 0, {$primary=>$eps, $secondary=>$sectok});
              $column++;
              last;
            }
            die "$nr:Inconsistent skeleton tokens: got $primtok, expected $colval";
          }
        }
      }
      $firstrun = 0; # the cn now already contains the first system
    }
    # make epsilons of all systems explicit
    foreach my $c (@$cn) {
      foreach my $s (0..$nSystems-1) {
        $c->{$s} = $eps if !defined $c->{$s};
      }
    }

    if ($verbose) {
      # verbose: emit the cn:
      print STDERR "CN before determinization:\n";
      foreach my $c (@$cn) {
        print STDERR join(" ", map { "$_:$c->{$_}" } sort {$a<=>$b} keys %$c)."\n";
      }
      print STDERR "\n";
    }

    # now determinize all columns in the cn
    my $detcn;
    foreach my $c (@$cn) {
      # convert each column c to arcs
      my $arcs;
      my $totarcs = 0;
      my $arclevel;
      foreach my $s (keys %$c) {
        my $token = $c->{$s};
        $arcs->{$token} ++;
        $totarcs ++;
        $arclevel->{$token}->[$s] = 1;
      }
      die "Lost some arcs: got $totarcs, expected $nSystems"
        if $totarcs != $nSystems;
      # collect arcs
      my $outarcs;
      my $token_produced_by_primary = $c->{$primary};
      foreach my $t (keys %$arcs) {
        # ensure zeros
        my @arclevel_w_zeroes = map { $arclevel->{$t}->[$_] || 0 } (0..$nSystems-1);
        my $prob = $arcs->{$t} / $totarcs;
        my $primary_arc = ( $t eq $token_produced_by_primary ? 1 : 0 );
        my $primary_word = ( $t ne $eps && $t eq $token_produced_by_primary ? 1 : 0 );
        push @$outarcs, [ $t,
                          $prob_mangler->($prob), # voting weight
                           "arclevel" =>
                             [ map {$ind_mangler->($_)} (@arclevel_w_zeroes) ],
                           "primarcs" =>
                             [ $ind_mangler->($primary_arc) ],
                           "primwords" =>
                             [ $ind_mangler->($primary_word) ],
                        ];
      }
      push @$detcn, $outarcs;
    }

    if ($verbose) {
      # verbose: emit the cn:
      print STDERR "CN after determinization:\n";
      foreach my $c (@$detcn) {
        print STDERR join(" | ", map { "@$_" } @$c)."\n";
      }
      print STDERR "\n";
    }
    push @rover, $detcn;
  }

  # combine all the confusion networks into one FSA
  # from start state to all the primaries
  # mangle all weights as desired
  my $sid = 1;
  my $unused_apriori_weight = $prob_mangler->(1); # taking this arc is no loss in prob
  my $unused_voting_weight = $prob_mangler->(1); # taking this arc is no loss in prob
  my @unused_word_weights = map { $ind_mangler->(0) } (1..$nSystems);
  my @unused_primary_weights = map { $ind_mangler->(0) } (1..$nSystems);
  my $unused_primary_arc = $ind_mangler->(0);
  my $unused_primary_word = $ind_mangler->(0);
  my $zeroweights = ",0" x ($nSystems+1); # the extra weight for overall voting
  foreach my $s (0 .. $nSystems-1) {
    print "0 $sid $eps "
      .make_feats({
         "apriori" => [ $prob_mangler->($apriori_weights[$s]) ],
         "voting" => [ $unused_voting_weight ],
         "sentlevel" => [ @unused_primary_weights ],
         "arclevel" => [ @unused_word_weights ],
         "primarcs" => [ $unused_primary_arc ],
         "primwords" => [ $unused_primary_word ]
       })
#       .join(",", ($prob_mangler->($apriori_weights[$s]),
#                   $unused_voting_weight,
#                   @unused_primary_weights,
#                   @unused_word_weights,
#                   $unused_primary_arc,
#                   $unused_primary_word,
#                   ))
      ."\n";
    my $sourcenode = $sid;
    $sid++;
    my $cn = $rover[$s];
    # walk all columns in the current cn
    my @amortized_primary_weights = @unused_primary_weights;
    $amortized_primary_weights[$s] = $cumul_mangler->(1)/scalar(@$cn);
      # this system gets 1/length of its cn, so that it adds up to 1
    foreach my $column (@$cn) {
      my $targetnode;
      if ($tokenize_at_underscore) {
        # see how many nodes do the paths need, split multiword tokens
        my $tottokens = 0;
        foreach my $arc (@$column) {
          my $origtoken = $arc->[0];
          my @tokens = split /_/, $origtoken;
          $tottokens += scalar @tokens;
          $arc->[0] = [ @tokens ];
        }
        # now all paths connect to the same target node, so we share that
        # node. How many intermediate nodes do we need?
        my $intermednodes = $tottokens - scalar(@$column);
        $targetnode = $sid + $intermednodes;
        foreach my $arc (@$column) {
          my $tokens = shift @$arc;
          my $voting_weight = shift @$arc;
          my $pathsourcenode = $sourcenode;
          my @path_amortized_primary_weights = @amortized_primary_weights;
          $path_amortized_primary_weights[$s] /= scalar(@$tokens);
          for(my $i=0; $i<@$tokens; $i++) {
            my $token = $tokens->[$i];
            $token =~ s/&underscore;/_/g;
            $token =~ s/&dollar;/\$/g;
            my $pathtargnode;
            if ($i == scalar(@$tokens)-1) {
              # last edge on this path
              $pathtargnode = $targetnode;
            } else {
              # a new node
              $pathtargnode = $sid;
              $sid++;
            }
            print "$pathsourcenode $pathtargnode $token "
              .make_feats({
                 "apriori" => [ $unused_apriori_weight ],
                 "voting" => [ $voting_weight ],
                 "sentlevel" => [ @path_amortized_primary_weights ],
                 @$arc  # covers arclevel, primarcs, primwords
               })
              ."\n";
            $pathsourcenode = $pathtargnode;
          }
        }
      } else {
        $targetnode = $sid;
        foreach my $arc (@$column) {
          my $token = shift @$arc;
          $token =~ s/&underscore;/_/g;
          $token =~ s/&dollar;/\$/g;
          my $voting_weight = shift @$arc;
          print "$sourcenode $targetnode $token "
            .make_feats({
               "apriori" => [ $unused_apriori_weight ],
               "voting" => [ $voting_weight ],
               "sentlevel" => [ @amortized_primary_weights ],
               @$arc  # covers arclevel, primarcs, primwords
             })
            ."\n";
        }
      }
      $sid++;
      $sourcenode = $targetnode;
    }
    print "$sourcenode\n"; # this is a final node
  }
  print "\n";

}

sub make_feats {
  my $feats = shift;

  my @out = ();
  foreach my $f (@wished_feats) {
    die "Unknown feature $f" if !defined $feats->{$f};
    push @out, @{$feats->{$f}};
  }
  return join(",", @out);
}
