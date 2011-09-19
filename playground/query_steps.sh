#!/bin/bash

# fancy queries of eman steps in current directory
# example usage:
#   ./query_steps.sh t mert l 50 s INITED v REFAUG=cs+lc
#   # return last 50 mert steps with status INITED and variable REFAUG set to 'cs+lc'
# 
# all options:
#   d ...  only DONE
#   do ...  execute command X for matched steps; this must be the last command
#           (all that follows is eval'ed)
#   dp ... X is a dependency
#   f ...  only FAILED
#   l ...  last X steps
#   lh ... last 10 steps
#   s ...  status X
#   t ...  type X (can be basically used like grep on step name, including date etc.)
#   v ...  variable (from eman.vars) VAR=value

steps=`ls | grep '^s\.' | sort -r -t'.' -k4`

while [ -n "$*" ]; do
  case $1 in
    "t")
      shift
      steps=`echo $steps | tr ' ' '\n' | grep $1`
      shift
      ;;
    "l")
      shift
      steps=`echo $steps | tr ' ' '\n' | head -$1`
      shift
      ;;
    "s")
      shift
      status=$1
      new_steps=""
      for i in $steps; do
        [ -z "`cat $i/eman.status | grep $status`" ] || new_steps="$new_steps $i"
      done
      steps="$new_steps"
      shift
      ;;
    "d")
      shift
      status=$1
      new_steps=""
      for i in $steps; do
        [ -z "`cat $i/eman.status | grep DONE`" ] || new_steps="$new_steps $i"
      done
      steps="$new_steps"
      shift
      ;;
    "f")
      shift
      status=$1
      new_steps=""
      for i in $steps; do
        [ -z "`cat $i/eman.status | grep '^FAILED'`" ] || new_steps="$new_steps $i"
      done
      steps="$new_steps"
      shift
      ;;
    "lh")    
      shift
      steps=`echo $steps | tr ' ' '\n' | head`
      shift
      ;;
    "v")
      shift
      new_steps=""
      for i in $steps; do
        [ -z "`cat $i/eman.vars | grep $1`" ] || new_steps="$new_steps $i"
      done
      steps="$new_steps"
      shift
      ;;
    "dp")
      shift
      new_steps=""
      for i in $steps; do
        [ -z "`cat $i/eman.deps | grep $1`" ] || new_steps="$new_steps $i"
      done
      steps="$new_steps"
      shift
      ;;
    "do")
      shift
      mydir=`pwd`
      for i in $steps; do
        cd $mydir/$i
        eval $*
      done
      cd $mydir
  esac
done

echo $steps | tr ' ' '\n'
