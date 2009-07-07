#!/bin/bash
# Prepare moses translation model, i.e. extract phrases

set -o pipefail
function die() { echo "$@" >&2; exit 1 ; }

[ ! -z "$SCRIPTS_ROOTDIR" ] \
  || die "Set \$SCRIPTS_ROOTDIR to the scripts release!"

if [ -z "$ALIAUG" ] || [ -z "$DECODINGSTEPS" ] \
  || [ -z "$SRCCORP" ] \
  || [ -z "$SRCAUG" ] \
  || [ -z "$TGTAUG" ] \
  ; then
  echo "You must set: "
  echo "  \$SRCCORP to source corpus name"
  echo "  \$TGTCORP to target corpus name, can be omitted if equal to SRCCORP"
  echo "  \$SRCAUG to the string describing lang+factors of src corpus"
  echo "  \$TGTAUG same for target, e.g. cs+0+1+pos+lc"
  echo "  \$ALICORP to target corpus name, can be omitted if equal to SRCCORP"
  echo "  \$ALIAUG to the string describing the 'language', e.g. 'ali'"
  echo "  \$DECODINGSTEPS to specification of decoding steps, e.g. 0a1-0+1-1"
  echo "And optionally:"
  echo "  \$REORDERING to reordering models, eg. orientation-bidirectional-fe"
  echo "  \$REORDFACTORS to factors to use, eg. 0,1-0+0-0"
  exit 1
fi

# TGT and ALI corp default to srccorp
[ ! -z "$TGTCORP" ] || TGTCORP=$SRCCORP
[ ! -z "$ALICORP" ] || ALICORP=$SRCCORP

if echo "$DECODINGSTEPS" | grep , ; then
  echo "\$DECODINGSTEPS ($DECODINGSTEPS) contains a comma! Use 'a' instead, e.g. 0a1-0+1-1"
  exit 1
fi

if [ -z "$REORDERING" ]; then
  REORDERING=distance
  REORDFACTORS="0-0"
  DOTREORDTAG=""
else
  if [ -z "$REORDFACTORS" ]; then
    echo "Set \$REORDFACTORS to the factors to use!"
    exit 1
  fi
  DOTREORDTAG=`echo ".$REORDERING.r$REORDFACTORS" | sed 's/\([a-z][a-z]\)[a-z]*/\1/g'`
fi

cat << KONEC > VARS
SRCCORP=$SRCCORP
TGTCORP=$TGTCORP
ALICORP=$ALICORP
SRCAUG=$SRCAUG
TGTAUG=$TGTAUG
ALIAUG=$ALIAUG
DECODINGSTEPS=$DECODINGSTEPS
REORDERING=$REORDERING
REORDFACTORS=$REORDFACTORS
KONEC

echo $SRCAUG > var-SRCAUG
echo $TGTAUG > var-TGTAUG

mydir=`pwd`

if [ $SRCCORP == $TGTCORP ] ; then
  echo SRC$SRCCORP+$SRCAUG.TGT+$TGTAUG.ALI$ALIAUG.DEC$DECODINGSTEPS$DOTREORDTAG > TAG
else
  echo SRC$SRCCORP+$SRCAUG.TGT$TGTCORP+$TGTAUG.ALI$ALIAUG.DEC$DECODINGSTEPS$DOTREORDTAG > TAG
fi

DECRYPT=../tools/decrypt_mapping_steps_for_training.pl
[ -x $DECRYPT ] || die "Missing: $DECRYPT"

DECRYPTEDSTEPS=`eval $DECRYPT $DECODINGSTEPS`


cat << KONEC > command
# This is the command to be run here
echo "=============================="
echo "== Started:   "\`date '+%Y%m%d-%H%M'\`
echo "== Hostname:  "\`hostname\`
echo "== Directory: "\`pwd\`
echo "=============================="

set -o pipefail
function die() { echo "\$@" >&2; exit 1 ; }

renice 10 \$\$

## Prepare the corpus from more factors
export SCRIPTS_ROOTDIR=$SCRIPTS_ROOTDIR
echo SCRIPTS_ROOTDIR=$SCRIPTS_ROOTDIR

mkdir corpus

cd corpus
wiseln \`../../augmented_corpora/augment.pl $SRCCORP/$SRCAUG\` corpus.src.gz \
  || die "Failed to clone source corpus"
wiseln \`../../augmented_corpora/augment.pl $TGTCORP/$TGTAUG\` corpus.tgt.gz \
  || die "Failed to clone target corpus"
cd ..

wiseln \`../augmented_corpora/augment.pl $ALICORP/$ALIAUG\` alignment.custom.gz \
  || die "Failed to clone alignment file"

alilen=\`zcat alignment.custom.gz | wc -l\`
srclen=\`zcat corpus/corpus.src.gz | wc -l\`
tgtlen=\`zcat corpus/corpus.tgt.gz | wc -l\`
if [[ \$alilen -ne \$srclen ]] \\
   || [[ \$alilen -ne \$tgtlen ]] \\
; then
  echo "Incompatible corpus lengths:"
  echo "\$alilen  alignment.custom.gz"
  echo "\$srclen  corpus.src.gz"
  echo "\$tgtlen  corpus.tgt.gz"
  exit 1
fi

mkdir model

tempdir=\`mktemp -d /mnt/h/tmp/exp.model.XXXXXX\`
echo "COPYING SELF TO TEMPDIR: \$tempdir"
rsync -avz * \$tempdir/ || die "Failed to rsync ourselves"
echo "COPIED, used disk space:"

df \$tempdir

if \\
  \$SCRIPTS_ROOTDIR/training/train-factored-phrase-model.perl \\
        --force-factored-filenames \\
	    --first-step 4 --last-step 6 \\
	    --root-dir \$tempdir \\
	    --alignment-file=alignment \\
	    --alignment=custom \\
	    --corpus=corpus/corpus \\
	    --f src --e tgt \\
	    $DECRYPTEDSTEPS \\
  && echo "Now will extract generation models" \\
  && \$SCRIPTS_ROOTDIR/training/train-factored-phrase-model.perl \\
        --force-factored-filenames \\
	    --first-step 8 --last-step 7 \\
	    --root-dir \$tempdir \\
	    --alignment-file=alignment \\
	    --alignment=custom \\
	    --corpus=corpus/corpus \\
	    --f src --e tgt \\
	    $DECRYPTEDSTEPS \\
; then
  success=1
  echo "COPYING TEMPDIR \$tempdir BACK"
  rsync -uavz \$tempdir/* ./ || exit 1
  echo "COPIED"

  echo Deleting \$tempdir
  rm -rf \$tempdir
else
  success=0
  rsync -uavz \$tempdir/log* ./ || exit 1
  echo "ONLY log copied back. Majority of files left here: \$tempdir"
fi

[ \$success == 1 ] || die "THERE WERE ERRORS!! See above."

echo "=============================="
echo "== Ended:     "\`date '+%Y%m%d-%H%M'\`
echo "== Hostname:  "\`hostname\`
echo "== Directory: "\`pwd\`
echo "=============================="
KONEC

if [ "$RUN" == "yes" ]; then
  sh command
fi
