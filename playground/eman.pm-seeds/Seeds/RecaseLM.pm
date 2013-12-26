use warnings;
use strict;
use MooseX::Declare;

class Seeds::RecaseLM extends Seeds::LM {
    use HasDefvar;
    
    has_defvar 'LANGUAGE'=>(help=>'Language to use');
    has_defvar 'CORPAUG'=> (help=>'the language+factors for the lm',
                            default_sub=>sub{
                                my $self=shift;
                                return $self->LANGUAGE."+form";
                            });
    
    has_defvar 'ORDER'=> (help=>'the lm order', default=>5);


    
    method help() {
        "slightly simpler eman lm seed for recasing";
    }

}

1;
