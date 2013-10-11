#!/bin/bash
# usage: ./subcorp.sh INCORPUS NEWNAME tokenfile TOKEN
# given a file where each line holds a distinguisting token, and given a corpus
# specifier such as:
#   newstest2013/csNmT1+stc+form
# registers a new corpus:
#   newstest2013-NEWNAME-TOKEN/csNmT1+stc+form

function die() { echo "$@" >&2; exit 1; }
set -o pipefail  # safer pipes

incorpus="$1"
newname="$2"
infile="$3"
token="$4"

[ ! -z "$token" ] || die "usage: $0 INCORPUS NEWNAME tokenfile TOKEN"

[ -e "$infile" ] || die "File not found: $infile"

grep -x "$token" "$infile" > /dev/null 2> /dev/null \
  || die "No lines in $infile contain '$token'"

./corpman $incorpus >/dev/null \
  || die "Corpus $incorpus not inited, please init it first."
./corpman --wait $incorpus > /dev/null \
  || die "Corpus $incorpus cannot be prepared"

# check the number of lines
gotlen=$(cat "$infile" | wc -l)
explen=$(./corpman --dump "$incorpus" | wc -l)
[ $gotlen == $explen ] \
  || die "Corpus $incorpus containts $explen lines, $infile contains $gotlen"

outcorpus=$(echo "$incorpus" | cut -d/ -f1)
outlang=$(echo "$incorpus" | cut -d/ -f2 | cut -d+ -f1)
outfacts=$(echo "$incorpus" | cut -d/ -f2 | cut -d+ -f2-)
outlinecount=$(grep -x "$token" "$infile" | wc -l)

outcorpus=$outcorpus-$newname-$token

echo "*** Preparing $outcorpus/$outlang+$outfacts with $outlinecount lines"

OUTCORP=$outcorpus OUTLINECOUNT=$outlinecount \
  OUTLANG=$outlang OUTFACTS=$outfacts \
  TAKE_FROM_COMMAND="../corpman $incorpus --dump | paste $infile - | grep '^$token[[:space:]]' | cut -f2-" \
  eman init corpus --start

