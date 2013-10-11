use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

class Align with EmanSeed {
    use HasDefvar;
    has_defvar 'GIZASTEP'=> (attrs=>'type=reqstep', help=>'where is GIZA/mGIZA and symal compiled'); 
    has_defvar 'CORPUS'=> (help=>'the corpus name');
    has_defvar 'SRCALIAUG'=>(help=>'lang+factors for the source side');
    has_defvar 'TGTALIAUG'=>(help=>'lang+factors for the target side');
    has_defvar 'TMPDIR'=>(help=>'temporary directory for Gizawrapper',attrs=>q(default='/mnt/h/tmp/'));
    has_defvar 'ALISYMS'=>(attrs=>'default=gdf,revgdf,gdfa,revgdfa,left,right,int,union', help=>'symmetrization methods, several allowed if delimited by comma');
    has_defvar 'ALILABEL'=>(attrs=>q(default=''), help=>'alignment "corpus" name, generated automatically if not given');
    has_defvar 'EMAN_CORES'=>(attrs=>q(default='1'), help=>'Core number for mgiza and SGE. Not used with GIZA++. Default=1 (just 1 core)');
    
    
    has_defvar 'TAKE_FROM_COMMAND'=>( help=>'run the command (no input) and collect its output', attrs=>q(default=''));

    method help() {
        "eman seed for word alignment"
    }
   

    has 'gizawrapper'=>(isa=>'Str', is=>'rw');

    method read_stuff_from_corpman(Str $aliaug) {
        my $res = $self->safeBacktick($self->playground.'/corpman --factorindex --init '.$self->CORPUS.'/'.$aliaug.' --bashvars=corpstep=stepname', e=>'can\'t corpman');
        $res =~ /corpstep=(.*)/ or die "Not defined corpstep in $res";
        my $step = $1;
        
        $res = $self->safeBacktick($self->playground.'/corpman --factorindex --init '.$self->CORPUS.'/'.$aliaug.' --bashvars=count=linecount', e=>'can\'t corpman');
        $res =~ /count=(.*)/ or die "Not defined count in $res";
        my $count = $1;
        
        return ($step, $count);
    }

    method register_corpora(Int $srccorplen) {
        my $i=1;
        for my $s (split(/,/, $self->ALISYMS)) {
            $self->safeSystem($self->playground."/corpman register -- alignment.gz $i ".
                $self->CORPUS." $s-".$self->ALILABEL." ali $srccorplen", e=>"Failed to register corpus");
            $i++;
        }
    }

    method init() {
        if (!$self->ALILABEL) {
            $self->ALILABEL($self->safeBacktick('echo '.$self->SRCALIAUG.'-'.$self->TGTALIAUG.q( | tr '+.' '--'")));
            $self->emanSaveDefvar("ALILABEL");
        }
       
        $self->gizawrapper($self->playground."/../scripts/gizawrapper.pl");
        
        if (!-x $self->gizawrapper) {
            $self->myDie( "gizawrapper not found: ".$self->gizawrapper);
        }

        my ($srccorpstep, $srccorplen) = $self->read_stuff_from_corpman($self->SRCALIAUG);
        my ($tgtcorpstep, $tgtcorplen) = $self->read_stuff_from_corpman($self->TGTALIAUG);
        if ($srccorplen != $tgtcorplen) {
            $self->myDie("Mismatching corpora lengths: src $srccorplen lines, tgt $tgtcorplen");
        }
        $self->emanAddDeps([$srccorpstep, $tgtcorpstep]);
        
        $self->register_corpora($srccorplen);
    }

    method prepare() {
        $self->GIZASTEP($self->safeBacktick('eman path '.$self->GIZASTEP));
    }

    method mkcorpus_command(Str $corpus, Str $aliaug, Str $short) {
        my $corpname=$corpus."/".$aliaug;
        my $cmn = $self->playground."/corpman";
        my $fn = "corpus.$short.gz";
        if (-e $fn) {
            $self->safeSystem("rm -f corpus.$short.gz");
        }
        $self->safeSystem($self->playground."/corpman --factorindex --wait ".$corpname,e=>"Failed to prepare $corpname");
        my @step_file_col = split(/\s+/, $self->safeBacktick("$cmn --factorindex $corpname"));

        my $step_file_col = join("\t", @step_file_col);
        my $step_file = $self->safeBacktick('eman path '.$step_file_col[0]);
        $step_file.="/".$step_file_col[1];
        my $scripts=$self->playground.'/../scripts';
        
        my $todo_first= $self->safeBacktick($cmn.' --factorindex --cmd '.$corpname);
        my $todo;
        
        # Source corpus contains just one column.
        if ( $step_file_col[2] == -1 ) {
            # Every token contains just the required factors.
            if ( $step_file_col[3] == -1 ) {
                $todo = "$scripts/wiseln $step_file corpus.$short.gz";
            } else 
            # There are additional factors that must be filtered out.
            {
                print "Selecting the factors from $step_file_col\n";
                $todo="$todo_first | $scripts/reduce_factors.pl ".$step_file_col[3]." | gzip -c > corpus.$short.gz";
            }
       } else
       # There are more than one column, the required column must be extracted.
       {
            # Every token contains just the required factors.
            if ( $step_file_col[3] == -1){
                print "Selecting the column from $step_file_col\n";
                $todo = "$todo_first | gzip -c > corpus.$short.gz";
            } else 
            # There are additional factors that must be filtered out.
            {
                print "Selecting the column and factors from $step_file_col\n";
                $todo = "$todo_first | $scripts/reduce_factors.pl ".$step_file_col[3]." | gzip -c > corpus.$short.gz";
            }
       }
       return $todo;
   }

    method run_giza_command() {
        my $bininfo="";
        if ($self->GIZASTEP =~ "mgiza") {
            $bininfo = " --mgizadir=".$self->GIZASTEP."/bin --mgizacores=".$self->EMAN_CORES." ";
        } else {
            $bininfo = " --bindir=".$self->GIZASTEP."/bin  ";
        }
        return $self->gizawrapper.
              " corpus.src.gz corpus.tgt.gz ".
              "--lfactors=0 --rfactors=0 ".
              "--tempdir=".$self->get_temp.
              $bininfo.
              "--dirsym=".$self->ALISYMS.
              " --drop-bad-lines ".
              " | gzip -c > alignment.gz";
                 
        
    }

    method check_lengths() {
        my $alilen=$self->safeBacktick("zcat alignment.gz | wc -l");
        my $srclen=$self->safeBacktick("zcat corpus.src.gz | wc -l");
        if ($alilen != $srclen ) {
            $self->myDie("Mismatched file lengths: ali $alilen, src $srclen");
        }
        return $alilen;
    }

    method get_temp() {
        my $tempdir=$ENV{TMPDIR};
        if (!defined $tempdir or (!-d $tempdir)) {
            $tempdir = "/tmp";
        }
        return $tempdir;
    }

    method run() {
        my $bc = $self->default_bash_context->copy;
        $bc->add_prefix('export SCRIPTS_ROOTDIR='.$self->GIZASTEP.'/moses/scripts');
        
        $self->safeSystem($self->mkcorpus_command($self->CORPUS, $self->SRCALIAUG, "src"),e=>"Failed to clone ".$self->CORPUS."/".$self->SRCALIAUG." src", bc=>$bc);
        $self->safeSystem($self->mkcorpus_command($self->CORPUS, $self->TGTALIAUG, "tgt"),e=>"Failed to clone ".$self->CORPUS."/".$self->TGTALIAUG." tgt", bc=>$bc);

        $self->safeSystem($self->run_giza_command, e=>"Giza failed!", bc=>$bc);

        $self->register_corpora($self->check_lengths());

        $self->safeSystem("rm ".$self->playground."/corpman.index");
    }


}


1;
