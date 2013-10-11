#!/bin/bash

if [[ -z "$STEMWORDS" ]]; then
    STEMWORDS=/home/odusek/work/tools/snowball/`arch`/stemwords
fi

while getopts "l:" OPTION; do
    case $OPTION in
        l)  LANGUAGE=$OPTARG;;
    esac
done
shift $((OPTIND-1))

if [[ -z "$LANGUAGE" ]]; then
    echo "Usage: snowball_wrapper.sh -l <LANGUAGE> < in > out"
    exit 1
fi

if [[ ! -x "$STEMWORDS" ]]; then
    echo "STEMWORDS path is not set up properly!"
    exit 1
fi

sed 's/\s\+/\n /g' | "$STEMWORDS" -l "$LANGUAGE" | perl -e '
my $buf = ""; 
my $first = 1; 
while(my $line = <>){ 
    $line =~ s/\r?\n$//; 
    if ($line !~ /^ /){ 
        if (!$first) { 
            chomp $buf; 
            print $buf . "\n";
        }
        $buf = $line;
        $first = 0; 
    } 
    else {
        $buf .= $line; 
    } 
} 
chomp $buf; 
print $buf . "\n";'
