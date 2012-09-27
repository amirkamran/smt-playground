#!/usr/bin/env perl
# Searches playground for log files that could be removed in order to spare disk space.
# Copyright © 2012 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use dzsys;

# Assume the current folder is the playground. Subfolders named s.* are the steps.
opendir(DIR, '.') or die("Cannot read current folder: $!");
my @steps = readdir(DIR);
closedir(DIR);
foreach my $step (@steps)
{
    # We are interested in steps only.
    next unless($step =~ m/^s\./);
    # Get the current status of the step. We will not remove or shorten logs of RUNNING and FAILED steps.
    my $status = dzsys::qticks("cat $step/eman.status");
    # Find logs in the step.
    opendir(DIR, $step) or die("Cannot read $step: $!");
    my @files = readdir(DIR);
    closedir(DIR);
    foreach my $file (@files)
    {
        # We are interested in logs only.
        next unless($file eq 'log' || $file =~ m/^log\.o\d+$/);
        my $size = -s "$step/$file";
        my $lines = dzsys::chompticks("cat $step/$file | wc -l");
        push(@{$map{$step}}, {'status' => $status, 'file' => $file, 'size' => $size, 'lines' => $lines});
    }
}
# Print statistics.
@steps = sort(keys(%map));
foreach my $step (@steps)
{
    my $type = 'unknown';
    if($step =~ m/^s\.([a-z]+)\./)
    {
        $type = $1;
    }
    my @logs = sort {$a->{file} cmp $b->{file}} (@{$map{$step}});
    foreach my $log (@logs)
    {
        print("$step\t$log->{file}\t$log->{size} bytes\t$log->{lines} lines\t$log->{status}\n");
        $total_size += $log->{size};
        $total_lines += $log->{lines};
        $total_logs++;
        $typemap{$type}{size} += $log->{size};
        $typemap{$type}{lines} += $log->{lines};
        $typemap{$type}{logs}++;
    }
    $total_steps++;
    $typemap{$type}{steps}++;
}
@types = sort(keys(%typemap));
foreach my $type (@types)
{
    print("TOTAL $type\t$typemap{$type}{steps} steps\t$typemap{$type}{logs} logs\t$typemap{$type}{size} bytes\t$typemap{$type}{lines} lines\n");
}
print("TOTAL\t$total_steps steps\t$total_logs logs\t$total_size bytes\t$total_lines lines\n");
