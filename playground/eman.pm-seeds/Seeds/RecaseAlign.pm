use MooseX::Declare;

class Seeds::RecaseAlign extends Seeds::IdentAlign{
    use HasDefvar;

    
    has 'CHECK_WORD_LENGTHS' => (is=>'ro', isa=>'Str', default=>'yes');
    has_defvar 'LANGUAGE'=>(help=>'Language to use');
    
    #overloading the defvars
    has 'SRCALIAUG'=> (is=>'ro', isa=>'Str', lazy=>1, 
                            default=>sub{
                                my $self=shift;
                                return $self->LANGUAGE."+lc";
                            });
    has 'TGTALIAUG'=> (is=>'ro', isa=>'Str', lazy=>1, 
                            default=>sub{
                                my $self=shift;
                                return $self->LANGUAGE."+form";
                            });

    method help() {
        "eman seed for recasing"
    }

}


1;



