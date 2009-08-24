#!/bin/bash
# Create a copy of a given corpus (and all its created factors [not
# combinations]) by copying only selected lines

function die() {
  echo "$@" >&2
  exit 1
}

set -o pipefail

greplinesf="$1"
srccorp="$2"
tgtcorp="$3"

if [ -z "$greplinesf" ] || [ -z "$srccorp" ] || [ -z "$tgtcorp" ]; then
  cat << KONEC >&2
usage: $0 lines-to-grep.file srccorpus tgtcorpus
... Creates tgtcorpus by copying all source and factor files from srccorpus
    selecting only lines whose numbers are listed in lines-to-grep.file
KONEC
  exit 1
fi

[ -e "$greplinesf" ] || die "Can't read $greplinesf"
[ -d "$srccorp" ] || die "Corpus not found: $srccorp"
[ ! -e "$tgtcorp" ] || die "Targetdir exists, delete it first: $tgtcorp"

mkdir "$tgtcorp" || die "Failed to create $tgtcorp"

for i in "$srccorp"/*.info; do
  cn=`basename $i | sed 's/\.info$//'`
  echo "Restricting files for $cn"
  [ -e "$srccorp/$cn.gz" ] || die "Not found $srccorp/$cn.gz"
  zcat "$srccorp/$cn.gz" \
  | greplines  "$greplinesf" \
  | gzip -c > "$tgtcorp/$cn.gz" \
  || die "Failed to create $tgtcorp/$cn.gz"
  cp "$srccorp/$cn.info" "$tgtcorp/$cn.info" \
  || die "Failed to create $tgtcorp/$cn.info"
  if [ -d "$srccorp/$cn.factors" ]; then
    for factf in "$srccorp/$cn.factors/*.gz"; do
      if [ -e "$factf" ]; then
        mkdir -p "$tgtcorp/$cn.factors" \
        || die "Failed to create $tgtcorp/$cn.factors"
        factorfname=`basename $factf`
        zcat "$srccorp/$cn.factors/$factorfname" \
        | greplines  "$greplinesf" \
        | gzip -c > "$tgtcorp/$cn.factors/$factorfname" \
        || die "Failed to create $tgtcorp/$cn.factors/$factorfname"
      fi
    done
  fi
done
