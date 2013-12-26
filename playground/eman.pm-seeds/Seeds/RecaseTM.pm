use warnings;
use strict;
use MooseX::Declare;

class Seeds::RecaseTM extends Seeds::TM {
    use HasDefvar;
    
    has_defvar 'LANGUAGE'=>(help=>'Language to use');
    has_defvar 'CORPAUG'=> (help=>'the language+factors for the lm',
                           );
    has_defvar 'SRCAUG'=>(
       help=>"the string describing lang+factors of src corpus", default_sub=>sub{
                                my $self=shift;
                                return $self->LANGUAGE."+lc";
                            });

    has_defvar 'TGTAUG'=>(
        help=>"the string describing lang+factors of tgt corpus", default_sub=>sub{
                                my $self=shift;
                                return $self->LANGUAGE."+form";
                            });
 


    
    method help() {
        "slightly simpler eman tm seed for recasing";
    }

}

1;
