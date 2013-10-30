use warnings;
use strict;
use MooseX::Declare;

class Seeds::BinarizeLM with (Roles::AccessesMosesBinaries) {
    use HasDefvar;
  
    has_defvar 'ORIG_LM'=>(help=>'lm step to binarize', type=>'reqstep');
    has_defvar 'ORDER'=> (help=>'the lm order' , inherit=>"ORIG_LM");

    has_defvar 'CORPAUG'=> (help=>'the language+factors for the lm. inherited from LM.', inherit=>"ORIG_LM");

   
    method help() {
        "eman seed for making binarized language model from non-binarized one. Not that much tested."
    }
  
    method init() {
    }

    method prepare() {
        $self->check_corpus_file();
        $self->copy_lm();
    }


    method run() {
        $self->binarize();    
    }


    has 'suffix' => (is=>'rw', isa=>'Str');
    has 'filename' => (is=>'rw', isa=>'Str');
    method check_corpus_file() {
        my $their_dir = $self->emanPath($self->ORIG_LM);
        if (-e "$their_dir/corpus.lm") {
            $self->filename($their_dir."/corpus.lm");
            $self->suffix(".lm");
        }
        elsif (-e "$their_dir/corpus.lm.gz") {
            $self->filename($their_dir."/corpus.lm.gz");
            $self->suffix(".lm.gz");
        } else {
            $self->myDie("Could not find lm file in $their_dir");
        }
    }
    
    method copy_lm() {
         $self->wiseLn($self->filename, "./original".$self->suffix);
    }

    method binarize() {
        $self->safeSystem($self->moses_binaries_dir."/build_binary trie original".$self->suffix." binarized");
    }

    


}

1;
