use warnings;
use strict;
use MooseX::Declare;

class Seeds::RecaseLM extends Seeds::Translate {
    use HasDefvar;
    
    #has_defvar 'LANGUAGE'=>(help=>'Language to use');
    #has_defvar 'CORPAUG'=> (help=>'the language+factors for the lm',
    #                        default_sub=>sub{
    #                            my $self=shift;
    #                            return $self->LANGUAGE."+form";
    #                        });
    
    #has_defvar 'ORDER'=> (help=>'the lm order', default=>5);

    has_defvar 'TRANSLATESTEP'=>(help=>'Translate step that we want to recase',
                                 type=>'reqstep');
    has_defvar 'TESTCORP'=> (help=>'the corpus to recase, automatically from TRANSLATESTEP',
                                inherit=>'TRANSLATESTEP');

    has_defvar 'SRCAUG'=> (help=>"What to recase; loaded automatically from TRANSLATESTEP",
                                default_sub=>sub{
                                    my $self=shift;
                                    my $translate_refaug = $self->emanGetVar($self->TRANSLATESTEP, "REFAUG"); 
                                    my ($lan, $orig_factor) = $translate_refaug =~/^([^\+]*)\+(.*)$/;
                                    if ($orig_factor ne "lc") {
                                        $self->myDie("factor not lc");
                                    }
                                    return $lan."_".($self->TRANSLATESTEP)."+lc";
                                });


    
    method help() {
        "recase step - basically translate step, just simpler";
    }

}

1;
