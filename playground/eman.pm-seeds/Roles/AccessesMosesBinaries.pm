use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::AccessesMosesBinaries with EmanSeed {
    use HasDefvar;

    has_defvar 'MOSESSTEP'=>(type=>"reqstep",
            help=>"the step containing compiled moses");    

    has 'mstep_dir' =>(isa=>'Str', is=>'rw', lazy=>1, default=>sub{
        my $self=shift;
        return $self->emanPath($self->MOSESSTEP)
    });


    method moses_binaries_dir() {
        return $self->moses_scripts_dir."/../bin";
    }

    method moses_scripts_dir() {
        return $self->mstep_dir."/moses/scripts";
    }

    method moses_cmd() {
        my $r = $self->mstep_dir."/bin/moses";
        if (!-x $r) {
            $self->myDie($self->moses_cmd." not executable!");
        }
        return $r;
    }

    method evaluator() {
        return $self->mstep_dir."/moses/bin/evaluator";
    }
    method filter_model_given_input(Str $dirname, Str $ininame, Str $input) {
   
        $self->safeSystem($self->moses_scripts_dir."/training/filter-model-given-input.pl".
                " --Binarizer=".$self->moses_binaries_dir."/processPhraseTable ".
                "$dirname ".$self->mydir."/$ininame $input ");
    }

    method _export_moses_rootdir() {
        return "export SCRIPTS_ROOTDIR=".$self->moses_scripts_dir;
    }
    
    around default_bash_context() {
        my $r = $self->$orig();
        if ($self->__is_preparing==0){
            $r->add_prefix($self->_export_moses_rootdir);
        }
        return $r;
    }
    
}


1;
