#!/bin/bash
for x in `eman select f` ; do
  jobs=`eman tb --status $x | grep Job: | grep -v 'Job: DONE' | wc -l`
  if [ "$jobs" == "0" ] ; then
    echo $x ... unexpected result of traceback
  elif [ "$jobs" == "1" ] ; then
    echo $x ... may be ready for continuing
  else
    echo $x ... some dependencies are not done
  fi
done
