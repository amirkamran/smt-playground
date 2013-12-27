use MooseX::Declare;

#align that uses giza
class Seeds::Align with (Roles::AccessesGiza,  Roles::GeneralAlign){
    use HasDefvar;
    


    method help() {
        "eman seed for word alignment"
    }

  
    method actual_align {
        $self->run_giza_command();
    }
           

    method run_giza_command() {
        $self->safeSystem($self->giza_command(
            $self->ALISYMS, 
            "corpus.src.gz",
            "corpus.tgt.gz",
            "alignment.gz"));
    }
    
   



}


1;
