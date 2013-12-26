use MooseX::Declare;

class Seeds::RecaseAlign extends Seeds::IdentAlign{
    use HasDefvar;

    has_defvar 'LANGUAGE'=>(help=>'Language to use');
    
    has_defvar 'SRCALIAUG'=>(help=>'lang+factors for the source side, automatically generated',
                             default_sub=>sub{
                                my $self=shift;
                                return $self->LANGUAGE."+lc";
                            });
    #overloading the defvars
    has_defvar 'TGTALIAUG'=>(help=>'lang+factors for the source side, automatically generated',
                             default_sub=>sub{
                                my $self=shift;
                                return $self->LANGUAGE."+form";
                            });
   
    method help() {
        "eman seed for alignment before recasing"
    }

}


1;



