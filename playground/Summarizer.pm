package Summarizer;
use strict;
#use warnings; # commented because marking of cells leads to many warnings
# prepares a summary of results given a prescription file

sub newscan {
  my $attrs = shift;
  my $stream = shift;

  my $self = Summarizer::new($attrs);
  $self->scan($stream);
  return $self;
}

sub new {
  my $self = shift; # supply attributes

  foreach my $attr (qw(title col rowtoks coltoks sortcol)) {
    die "Attribute $attr required for $self->{title}"
      if !defined $self->{$attr};
  }
  # other important attributes: subtitle reqtoks forbtoks
  $self->{reqtoks} =~ s/^[ \n\t]*|[ \n\t]*$//g;
  $self->{forbtoks} =~ s/^[ \n\t]*|[ \n\t]*$//g;
  $self->{rowtoks} =~ s/^[ \n\t]*|[ \n\t]*$//g;
  $self->{coltoks} =~ s/^[ \n\t]*|[ \n\t]*$//g;

  $self->{reqtoksf} = [ split /[ \n\t]+/, $self->{reqtoks} ];
  $self->{forbtoksf} = [ split /[ \n\t]+/, $self->{forbtoks} ];
  $self->{rowtoksf} = [ split /[ \n\t]+/, $self->{rowtoks} ];
  $self->{coltoksf} = [ split /[ \n\t]+/, $self->{coltoks} ];

  $self->{blankvalue} ||= "-";
  $self->{verbose} ||= 0;

  bless $self;
  return $self;
}

sub collect_tokens {
  # given a regular expression, collect all occurrences of it
  # special flags can be given using a few letters followed by ^ (not part of
  # the regexp), e.g. u^mytoken to set 'uniq' flag
  # Flags:
  #   u ... uniq, ignore repetitive occurrences of the token
  #   c ... uniq -c, count repetitive occurrences of the token
  #   i ... insensitive, ignore case # not yet implemented
  #   f ... first occurrence only, don't collect all
  my $self = shift;
  my $origtokenre = shift;
  my $line = shift;
  my @out = ();

  # remove flags from origtokenre
  $origtokenre =~ s/^([uicf])\^//;
  my $flags = $1;

  while ($line =~ /$origtokenre/) {
    my @matches = map {substr $line, $-[$_], $+[$_] - $-[$_]} (1..$#-);
    # delete this token occurrence
    my $oldline = $line;
    substr($line, $-[0], $+[0] - $-[0], "");
    die "Avoiding loop with re $origtokenre and line: $line" if $line eq $oldline;
    my $tokenre = $origtokenre;
    if ($tokenre =~ /\(/) {
      print "Token $tokenre MATCHES: @matches\n" if $self->{verbose} >= 3;
      foreach my $m (@matches) {
        $tokenre =~ s/\([^\(\)]+\)/$m/;
      }
    }
    push @out, (defined $self->{tokenmap}->{$tokenre} ? $self->{tokenmap}->{$tokenre} : $tokenre);
  }

  if ($flags =~ /f/) {  # first occurrence only
    return () if 0 == scalar @out;
    return $out[0];
  } elsif ($flags =~ /u/) {  # uniq the occurrences
    return () if 0 == scalar @out;
    my %uniq = map { ($_, 1) } @out;
    return sort {$a cmp $b} keys %uniq;
  } elsif ($flags =~ /c/) {  # count the number of occurrences
    return () if 0 == scalar @out;
    return ( scalar(@out)."*".$out[0] );
  } else {
    return @out;
  }
}

sub scan {
  my $self = shift;
  my $lines = shift;

  print "\n===== $self->{title} ====\n";
  print "$self->{subtitle}\n" if $self->{subtitle} && $self->{subtitle} ne "";
  print "Common properties: ".join(" ", @{$self->{reqtoksf}})."\n";
  print "Forbidden properties: ".join(" ", @{$self->{forbtoksf}})."\n";

  my $cols_to_pick = $self->{col};
  my @cols_to_pick = ();
  foreach my $col_to_pick (split /,/, $cols_to_pick) {
    if ($col_to_pick !~ /^[0-9]+$/) {
      # we need to get the column number from the title line
      for(my$i = 0; $i < scalar @{$lines->[0]}; $i++) {
        if ($lines->[0]->[$i] eq $col_to_pick) {
          $col_to_pick = $i;
          last;
        }
      }
  
      die "Column $col_to_pick not found in $lines->[0]"
        if $col_to_pick !~ /^[0-9]+$/;
    }
    push @cols_to_pick, $col_to_pick;
  }

  my %coldef; my %rowdef;
  my @coldef; my @rowdef;
  my %table;
  my %tableinfo;
  my %used = ();
  LINE: foreach my $line (@$lines) {
    foreach my $r (@{$self->{reqtoksf}}) {
      if ($line->[0] !~ /$r/) {
        print "Removing due to missing $r: ".$line->[0]."\n" if $self->{verbose} >= 2;
        next LINE;
      }
    }
    foreach my $f (@{$self->{forbtoksf}}) {
      if ($line->[0] =~ /$f/) {
        print "Removing due to forbidden $f: ".$line->[0]."\n" if $self->{verbose} >= 2;
        next LINE;
      }
    }
    print "Picking rowids and colids from: ".$line->[0]."\n" if $self->{verbose} >= 2;
    my @rowid = ();
    foreach my $temprt (@{$self->{rowtoksf}}) {
      my $rt = $temprt;
      push @rowid, ($self->collect_tokens($rt, $line->[0]));
    }
    my @colid = ();
    foreach my $ct (@{$self->{coltoksf}}) {
      push @colid, ($self->collect_tokens($ct, $line->[0]));
    }
    
    my $rowid = "@rowid";
    my $colid = "@colid";
    if (!defined $rowdef{$rowid}) {
      push @rowdef, $rowid;
      $rowdef{$rowid} = 1;
    }
    if (!defined $coldef{$colid}) {
      push @coldef, $colid;
      $coldef{$colid} = 1;
    }
    my $pos = "$rowid\t$colid";
    my $value = join(",", map { $line->[$_] } @cols_to_pick);
    if (defined $table{$pos} 
      && ($table{$pos} ne $value || $self->{verbose}>0)) {
      sub move_last_col_to_front {
        my $cols = shift;
        my @cols = split /\t/, $cols;
        my $last = pop @cols;
        unshift @cols, $last;
        return join("\t", @cols);
      }
      print "Replaced: ".move_last_col_to_front($tableinfo{$pos})."\n";
      print "With new: ".move_last_col_to_front($line->[0])."\n";
      delete $used{"@rowid\t@colid\t$tableinfo{$pos}"};
    }
    if (defined $self->{collectdelim}) {
      $table{$pos} .= $self->{collectdelim} if defined $table{$pos};
      $table{$pos} .= $value;
    } else {
      $table{$pos} = $value;
    }
    $tableinfo{$pos} = $line->[0];
    $used{"@rowid\t@colid\t$line->[0]"} = 1;
  }
  print "\n".join("", map {"Using: ".$_."\n"} sort keys %used)
    if ($self->{verbose} || defined $rowdef{""} || defined $coldef{""})
      && ($self->{verbose} >= 0);
  print "\n";
  # Print column headers
  foreach my $col (@coldef) {
    print "\t$col";
  }
  print "\n";
  my @sortedrowdef;
  if (defined $self->{sortcol}) {
    @sortedrowdef = sort {
          ( $table{"$a\t$self->{sortcol}"} || 0 )
      <=> ($table{"$b\t$self->{sortcol}"} || 0 ) } @rowdef;
  } else {
    @sortedrowdef = @rowdef;
  }
  # Prepare the table
  my @tab;
  my @mark;
  for(my $r=0; $r<=$#sortedrowdef; $r++) {
    my $row = $sortedrowdef[$r];
    my $val_to_colidx = undef;
    for(my $c=0; $c<=$#coldef; $c++) {
      my $col = $coldef[$c];
      my $pos = "$row\t$col";
      $tab[$r][$c] =
        defined $table{$pos} ? $table{$pos} : $self->{"blankvalue"};
      push @{$val_to_colidx->{$tab[$r][$c]}}, $c;
    }
    my @sortedvals = sort {$b<=>$a} keys %$val_to_colidx;
    foreach my $c (@{$val_to_colidx->{$sortedvals[0]}}) {
      $mark[$r][$c] = "^"; # mark this node as horizontal maximum
    }
  }
  for(my $c=0; $c<=$#coldef; $c++) {
    my $val_to_rowidx = undef;
    for(my $r=0; $r<=$#sortedrowdef; $r++) {
      push @{$val_to_rowidx->{$tab[$r][$c]}}, $r;
    }
    my @sortedvals = sort {$b<=>$a} keys %$val_to_rowidx;
    foreach my $r (@{$val_to_rowidx->{$sortedvals[0]}}) {
      $mark[$r][$c] = defined$mark[$r][$c]?"*":">";
        # mark this node as ultimate or vertical maximum
    }
  }

  # Print the table
  for(my $r=0; $r<=$#sortedrowdef; $r++) {
    my $row = $sortedrowdef[$r];
    print "$row";
    for(my $c=0; $c<=$#coldef; $c++) {
      print "\t$tab[$r][$c]";
      print $mark[$r][$c] if defined $self->{print_marks} && defined $mark[$r][$c];
    }
    print "\n";
  }
  print "\n";
}


sub load {
  my $stream = shift;
  my @data;
  while (<>) {
    chomp;
    my @line = split /\t/;
    push @data, [ ($_, @line) ];
  }
  return [@data];
}



1;
