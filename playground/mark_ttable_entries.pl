#!/usr/bin/perl

use strict;
use warnings;

my $method = shift;

die "usage: $0 METHOD
Where METHOD is:
- equal
- trust (with some hardwired constants
" if !defined $method;

my %methods = qw(equal 10000 trust 10001);
my $method_int = $methods{$method};
die "Unknown method '$method'" if !defined $method_int;

my $e = 2.71828182846;
while (my $line = <>) {
        chomp $line;

        my @line = split(/\|\|\|/, $line);

        my $phrase1 = $line[0];
        $phrase1 =~ s/^\s+//g;
        $phrase1 =~ s/\s+$//g;
        my $phrase2 = $line[1];
        $phrase2 =~ s/^\s+//g;
        $phrase2 =~ s/\s+$//g;


        my $add_val = 1;
        if ($method_int == 10000) {
          if ($phrase1 eq $phrase2) {
                  $add_val = $e;
          }
        } else {
          # method == trust
          my $vals = $line[2];
          $vals =~ s/^\s//g;
          $vals =~ s/\s$//g;
          my @vals = split(/\s+/, $vals);
          my $counts = $line[4];
          $counts =~ s/^\s//g;
          $counts =~ s/\s$//g;
          my @counts = split(/\s+/, $counts);
  
          if ($vals[2] > 0.7 and $counts[0] > 2 and $counts[1] > 2) {
                  $add_val = $e;
          }
        }


        my $old_val = $line[2];
        my $new_val = $line[2];
        $new_val =~ s/\s+$//g;  
        $new_val = $new_val . ' ' . $add_val;

        $line[2] = $new_val;
        print join(' ||| ', @line);
        print "\n";
}
