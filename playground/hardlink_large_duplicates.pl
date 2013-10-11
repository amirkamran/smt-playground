#!/usr/bin/env perl
# Identifies large duplicate files and replaces them with hardlinks.
# Distributed version, each candidate tuple is submitted as a separate job (running diff on large files takes time).
# At the same time, this script can also be called as the one that executes the job:
#    hardlink_large_duplicates.pl
#       Without arguments, it traverses the subtree of the current folder, looks for files and submits jobs to cluster.
#    hardlink_large_duplicates.pl file1 file2 file3...
#       Arguments are interpreted as paths to files.
#       If two files are identical, they are merged.
#       If there are more than two files, we expect that all of them are identical.
#       We do not compare all pairs. Once we encounter a file that is not identical to the first one, we stop.
# Copyright © 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
# Dan's libraries.
use find;
use cluster;

if(scalar(@ARGV)>=2)
{
    compare_and_merge_files(@ARGV);
}
else
{
    # Assume that the current folder is the playground and all subfolders named s.something are steps.
    # Traverse the step subtrees recursively, remember all files larger than 1,000,000 bytes (one hardlink per inode!)
    find::go('.', \&cache_size);
    # %cache now contains list of files for each known size.
    # Look for sizes with more than one file.
    @sizes = sort {$b<=>$a} (keys(%cache));
    $total_gain = 0;
    $total_files = 0;
    foreach my $size (@sizes)
    {
        my @files = @{$cache{$size}};
        my $n = scalar(@files);
        if($n>1)
        {
            my $gain = ($n-1)*$size;
            $total_gain += $gain;
            $total_files++;
            print STDERR ("We could merge the following files (gain = $gain B):\n");
            foreach my $file (@files)
            {
                print STDERR ("\t$file\n");
            }
            submit_compare_and_merge_files(@files);
        }
    }
    print STDERR ("Total $total_files files could be turned into hardlinks.\n");
    print STDERR ("Total gain could be $total_gain bytes.\n");
}



#------------------------------------------------------------------------------
# Get file size. Remember paths and sizes of large files.
#------------------------------------------------------------------------------
sub cache_size
{
    my $path = shift;
    my $object = shift;
    my $type = shift;
    my $pobject = "$path/$object";
    # If this is a file, get its size.
    if($type eq 'o')
    {
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($pobject);
        # We are interested in large files only. Do not waste time comparing lots of small files where little disk space can be gained.
        # We define 'large' as million bytes or more.
        # For already hardlinked files, we are only interested in the first filename we encounter.
        if($size>=1000000 && !$inodemap{$ino})
        {
            push(@{$cache{$size}}, $pobject);
            # Report progress.
            printf STDERR ("%12d B\t%s\n", $size, $pobject);
        }
        $inodemap{$ino}++;
    }
    else
    {
        print STDERR ("$pobject\n");
    }
    # Allow find to go inside if this is a subfolder that is readable and executable.
    return $type eq 'drx';
}



#------------------------------------------------------------------------------
# Takes a list of files. Submits a cluster job to check and merge them.
#------------------------------------------------------------------------------
sub submit_compare_and_merge_files
{
    my @files = @_;
    die("At least two files expected.") if(scalar(@files)<2);
    ###!!! Měli bychom kontrolovat, že cesty nejsou identické a že už teď nejde o hardlinky na stejný inode. Abychom nedělali zbytečnou práci.
    my $command = "$0 ".join(' ', @files);
    cluster::qsub('command' => $command);
}



#------------------------------------------------------------------------------
# Takes a list of files. If they are identical, merges them using hardlinks.
#------------------------------------------------------------------------------
sub compare_and_merge_files
{
    my $first = shift;
    my @files = @_;
    foreach my $second (@files)
    {
        if(are_identical_files($first, $second))
        {
            hardlink_files($first, $second);
        }
    }
}



#------------------------------------------------------------------------------
# Tells whether two files are identical.
#------------------------------------------------------------------------------
sub are_identical_files
{
    my $f1 = shift;
    my $f2 = shift;
    print STDERR ("Comparing...\n\t$f1\n\t$f2\n");
    open(F1, $f1) or die("Cannot read $f1: $!");
    open(F2, $f2) or die("Cannot read $f2: $!");
    binmode(F1, ':raw');
    binmode(F2, ':raw');
    my ($rf1, $rf2);
    while($rf1 = <F1>)
    {
        $rf2 = <F2>;
        return 0 unless($rf1 eq $rf2);
    }
    close(F1);
    close(F2);
    return 1;
}



#------------------------------------------------------------------------------
# Gets two or more files. Turns the second and all subsequent files into hard-
# links to the first file.
#------------------------------------------------------------------------------
sub hardlink_files
{
    my @files = @_;
    my $first = shift(@files);
    foreach my $second (@files)
    {
        print STDERR ("Hardlinking\n\t$second to\n\t$first.\n");
        unlink($second) and link($first, $second) or print STDERR ("Cannot hardlink $second to $first: $!\n");
    }
}
