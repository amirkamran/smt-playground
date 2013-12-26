use warnings;
use strict;
use MooseX::Declare;

class Seeds::Giza with Roles::CompilesGiza {
    method help() {
        " eman seed for compiling giza"
    }
    
    method init(){
    
    }

    method prepare() {
    }

    method run() {
        $self->giza();
    }
}

1;
