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
    my $status = dzsys::qcticks("cat $step/eman.status");
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
        # Shorten long logs of DONE, OBSOLETE and ABOLISHED steps.
        if($status =~ m/^(DONE|OBSOLETE|ABOLISHED)$/ && $lines>200)
        {
            my $tmp = "$file.$$";
            print STDERR ("Reducing $step/$file, using temporary file $step/$tmp...\n");
            open(IN, "$step/$file") or die("Cannot read $step/$file: $!");
            open(OUT, ">$step/$tmp") or die("Cannot write $step/$tmp: $!");
            my $i = 0;
            while(<IN>)
            {
                if($i<50 || $i>=$lines-50)
                {
                    print OUT;
                }
                elsif($i==50)
                {
                    print OUT ("...\n");
                }
                $i++;
            }
            close(IN);
            close(OUT);
            dzsys::saferun("mv $step/$tmp $step/$file");
            $total_logs_shortened++;
            $total_lines_removed += $lines-100;
            $total_bytes_removed += $size-(-s "$step/$file");
        }
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
            $total_logs_shortened++;
            $total_lines_removed += $lines-100;
print("REMOVED\t$total_bytes_removed bytes\t$total_lines_removed lines\tfrom $total_logs_shortened logs\n");
