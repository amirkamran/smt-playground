#!/bin/bash
# given a dir name returns a short info describing the status of the logfile:

if [ -z $1 ]; then
  echo "usage: loginfo.sh expdir" >&2
  exit 1
fi

function print_info () {
  lf="$1/log"
  lastlog=`ls $lf.o* 2>/dev/null| tail -1`
  if [ -e "$lastlog" ]; then
    # ufal naming convention is different
    lf="$lastlog"
  fi
  
  if [ -e $lf ]; then
    tail -1 $lf | cut -c1-10 | sed 's/==========/===FINI?==/' | sed 's/^ *$/running.../'
  else
    if [ -d $1 ]; then
      echo "-prepared-"
    else
      echo "-nonexist-"
    fi
  fi
}

if [ "a$1" == "a-" ]; then
  while read r; do
    print_info $r
  done
else
  print_info $1
fi
