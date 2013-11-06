use MooseX::Declare;


#general alignment
#doesn't actually run the alignment
#Seeds::Align runs giza alignment, Seeds::IdentAlign runs differen alignment
role Roles::GeneralAlign with (Roles::KnowsCorpman){
    use HasDefvar;
    has_defvar 'CORPUS'=> (help=>'the corpus name');
    has_defvar 'SRCALIAUG'=>(help=>'lang+factors for the source side');
    has_defvar 'TGTALIAUG'=>(help=>'lang+factors for the target side');
    has_defvar 'ALILABEL'=>(default=>'', help=>'alignment "corpus" name, generated automatically if not given');

    method prepare(){
    }

    requires 'actual_align';
    method run() {
        $self->make_align_corpus;
        $self->actual_align();

        $self->register_corpora($self->check_lengths());

        $self->restart_corpman();
    }

    method init() {
        if (!$self->ALILABEL) {
            $self->ALILABEL($self->safeBacktick('echo '.$self->SRCALIAUG.'-'.$self->TGTALIAUG.q( | tr '+.' '--'")));
        }
      
        my ($srccorpstep, $srccorplen) = $self->read_basics_from_corpman($self->SRCALIAUG);
        my ($tgtcorpstep, $tgtcorplen) = $self->read_basics_from_corpman($self->TGTALIAUG);
        if ($srccorplen != $tgtcorplen) {
            $self->myDie("Mismatching corpora lengths: src $srccorplen lines, tgt $tgtcorplen");
        }
        $self->emanAddDeps([$srccorpstep, $tgtcorpstep]);
        
        $self->register_corpora($srccorplen);
    }

    method read_basics_from_corpman(Str $aliaug) {
        my $step = $self->read_bashvar_from_corpman("stepname",$aliaug);
        my $count = $self->read_bashvar_from_corpman("linecount",$aliaug);
        
        return ($step, $count);
    }

    method read_bashvar_from_corpman(Str $varname, Str $aliaug) {
        return  $self->read_corp_info( 
                                corpname=>$self->CORPUS,
                                aug=>"aliaug",
                                var=>$varname);        
    }

    method make_align_corpus(){
        $self->mkcorpus_do($self->CORPUS, $self->SRCALIAUG, "src");
        $self->mkcorpus_do($self->CORPUS, $self->TGTALIAUG, "tgt");
    }
 
    method check_lengths() {
        my $alilen=$self->safeBacktick("zcat alignment.gz | wc -l");
        my $srclen=$self->safeBacktick("zcat corpus.src.gz | wc -l");
        if ($alilen != $srclen ) {
            $self->myDie("Mismatched file lengths: ali $alilen, src $srclen");
        }
        return $alilen;
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

}
1;
