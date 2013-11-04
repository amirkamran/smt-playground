use MooseX::Declare;

class Seeds::Align with (Roles::KnowsMkcorpus, Roles::AccessesGiza, Roles::KnowsCorpman) {
    use HasDefvar;
    has_defvar 'CORPUS'=> (help=>'the corpus name');
    has_defvar 'SRCALIAUG'=>(help=>'lang+factors for the source side');
    has_defvar 'TGTALIAUG'=>(help=>'lang+factors for the target side');
    has_defvar 'ALISYMS'=>(default=>'gdf,revgdf,gdfa,revgdfa,left,right,int,union', help=>'symmetrization methods, several allowed if delimited by comma');
    has_defvar 'ALILABEL'=>(default=>'', help=>'alignment "corpus" name, generated automatically if not given');
    
    
    has_defvar 'TAKE_FROM_COMMAND'=>( help=>'run the command (no input) and collect its output', default=>'');

    method help() {
        "eman seed for word alignment"
    }

    method init() {
        if (!$self->ALILABEL) {
            $self->ALILABEL($self->safeBacktick('echo '.$self->SRCALIAUG.'-'.$self->TGTALIAUG.q( | tr '+.' '--'")));
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
    }
   
    method run() {
        $self->make_align_corpus;
        $self->run_giza_command();

        $self->register_corpora($self->check_lengths());

        $self->restart_corpman();
    }

    method make_align_corpus(){
        $self->mkcorpus_do($self->CORPUS, $self->SRCALIAUG, "src");
        $self->mkcorpus_do($self->CORPUS, $self->TGTALIAUG, "tgt");
    }

   

    method read_bashvar_from_corpman(Str $varname, Str $aliaug) {
        return  $self->read_corp_info( 
                                corpname=>$self->CORPUS,
                                aug=>"aliaug",
                                var=>$varname);        
    }

    method read_stuff_from_corpman(Str $aliaug) {
        my $step = $self->read_bashvar_from_corpman("stepname",$aliaug);
        my $count = $self->read_bashvar_from_corpman("linecount",$aliaug);
        
        return ($step, $count);
    }

    method register_corpora(Int $srccorplen) {
        my $i=1;
        for my $s (split(/,/, $self->ALISYMS)) {
            $self->promise_corp(filename=>"alignment.gz", 
                                column=>$i, 
                                corpname=>$self->CORPUS,
                                lang=>$s."-".$self->ALILABEL,
                                factors=>"ali",
                                count=>$srccorplen);
            #die "BBBB";
            $i++;
        }
    }
        
    method gizawrapper() {
        my $r = $self->scriptsDir."/gizawrapper.pl";
        if (!-x $r) {
            $self->myDie( "gizawrapper not found: ".$self->gizawrapper);
        }
        return $r;
    }

    method run_giza_command() {
        $self->safeSystem($self->giza_command());
    }

    method giza_command() {

        return $self->gizawrapper.
              " corpus.src.gz corpus.tgt.gz ".
              "--lfactors=0 --rfactors=0 ".
              "--tempdir=".$self->get_temp.
              $self->giza_info_for_wrapper.
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





}


1;
