#!/usr/bin/perl -w

# merge moses.ini files

use strict;
use Switch;
use Cwd('abs_path');
use Getopt::Long;

my ($verbose, $append_unknown);

die usage() if ! GetOptions(
    "append-unknown" => \$append_unknown,
    "verbose|v" => \$verbose);

die usage() if ! @ARGV;
my @filenames = @ARGV;
my %sections; # hash of hashes of arrays: sections{sections}{files}[lines]
my @section_names; # used for keeping sections in original order

# read contents of all files 
for my $filename (@filenames) {
    my $current_section;
    open my $handle, $filename or die("Can't open file $filename: $!\n");
    while (<$handle>) {
        chomp;
        my $line = $_;
        # enter section
        if ($line =~ m/^\[([^\]]+)\]\s*$/) {
            $current_section = $1;
            if (! is_in_string_array(\@section_names, $current_section)) {
                push(@section_names, $current_section);
            }
        # skip comments, empty lines and the beginning of the file
        } elsif ($line !~ m/^#/ and $line !~ m/^\s*$/ and $current_section) {
            push(@{$sections{$current_section}{$filename}}, $line);
        }
    }
}

print "# Generated by merge_moses_models.pl from files:\n#\n";
print "# ", abs_path($_), "\n" for (@filenames);
print "\n";

for (@section_names) {
    switch ($_) {
        # TODO cover all sections
        # XXX lmodel-file and weight-l should be concatenated, this is a quick
        # fix for merging in eman seed model to work
        case "input-factors"    { merge_output_once($_); }
        case "mapping"          { merge_concat($_); }
        case "ttable-file"      { merge_concat($_); }
        case "generation-file"  { merge_concat($_); }
        case "lmodel-file"      { merge_output_once($_); }
        case "ttable-limit"     { merge_output_once($_); }
        case "weight-d"         { merge_output_once($_); }
        case "weight-l"         { merge_output_once($_); } 
        case "weight-t"         { merge_concat($_); }
        case "weight-generation"{ merge_concat($_); }
        case "weight-w"         { merge_output_once($_); }
        case "distortion-limit" { merge_output_once($_); }
        else {
            if ($append_unknown) {
                merge_concat($_);
            } else {
                print STDERR "Skipping unknown section: $_\n";
            }
        }
    }
}

# returns 1 if section exists, 0 otherwise
sub warn_missing_section
{
    my $section = shift;
    my $filename = shift;
    if (! defined@{$sections{$section}{$filename}}) {
        print STDERR "Section $section not found in file " .
            abs_path($filename) . "\n";
        return 0;
    } else {
        return 1;
    }
}

sub merge_concat
{
    my $section = shift;
    print "[$section]\n";
    for my $filename (@filenames) {
        print "# ", abs_path($filename), "\n" if $verbose;
        warn_missing_section($section, $filename);
        for my $line (@{$sections{$section}{$filename}}) {
            print "$line\n";
        }
    }
    print "\n";
}

sub merge_output_once
{
    my $section = shift;
    print "[$section]\n";
    print "# ", abs_path($filenames[0]), "\n" if $verbose;
    for my $line (@{$sections{$section}{$filenames[0]}}) {
        print "$line\n";
    }
    print "\n";

    # check if other files define this section the same way
    my (undef, @other_files) = @filenames;
    for my $filename (@other_files) {
        my $index = 0;
        warn_missing_section($section, $filename);
        for my $line (@{$sections{$section}{$filenames[0]}}) {
            if (! defined @{$sections{$section}{$filename}}[$index] or
                @{$sections{$section}{$filename}}[$index] ne $line) {
                print STDERR "Section $section differs in file " .
                    abs_path($filename) . "\n";
            }
            ++$index;
        }        
    }
}

sub is_in_string_array
{
    my $ref_array = shift;
    my $value = shift;
    for (@$ref_array) { return 1 if $value eq $_; }
    return 0;
}

sub usage
{
    return "Usage: ./merge_moses_models.pl [options] file [file] [file] ...\n" .
        "Options:\n" .
        "-verbose|-v        Verbose output\n" .
        "-append-unknown    Merge unknown sections by appending\n"; 
}

