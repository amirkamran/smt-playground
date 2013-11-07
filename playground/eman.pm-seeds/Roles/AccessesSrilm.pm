use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::AccessesSrilm with EmanSeed {
    use HasDefvar;
    has_defvar 'SRILMSTEP'=> (
        
        type=>'reqstep',
        help=>'where is srilm compiled');

    #I have to have it like a property
    #in order to stop having infinite recursion
    #in run phase
    has 'srilm_dir' =>(isa=>'Str', is=>'rw', lazy=>1, default=>sub{
        my $self = shift;
        if (!$self->SRILMSTEP) {
            $self->myDie("Not defined SRILMSTEP.");
        }
        return $self->emanPath($self->SRILMSTEP); 
    });


    method srilm_path() {
        return $self->safeBacktick('cat '.$self->srilm_dir.'/srilm.path');
    }
    method srilm_dir() {
       
    }

    method srilm_dir_bin() {
          return $self->srilm_dir."/srilm/bin/";
    }
    
    method srilm_dir_686() {
          return $self->srilm_dir."/srilm/bin/i686";
    }
    
    around default_bash_context() {
        my $r = $self->$orig();
        if ($self->__is_preparing==0){
            $r->add_prefix($self->_export_srilm_path);
        }
        return $r;
    }


    method _export_srilm_path() {
        return "export PATH=".$self->srilm_dir_bin.":".$self->srilm_dir_686.":\$PATH";
    }

#    method make_lm_cmd() {
#        return srilm_cmd_path("make-big-lm");
#    }
#    method ngram_count_cmd() {
#        return srilm_cmd_path("ngram-count");
#    }

#    method srilm_cmd_path(Str $what) {
#        if (-x $self->srilm_path."/bin/$what") {
#            return $self->srilm_path."/bin/$what";
#        }
#        if (-x $self->srilm_path."/bin/i686/$what") {
#            return $self->srilm_path."/bin/i686/$what";
#        }
#
#        $self->myDie("Cannot find $what in srilm step :( ");
#    }


}

1;
