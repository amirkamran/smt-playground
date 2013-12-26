use warnings;
use strict;
use MooseX::Declare;


class Seeds::MGiza with Roles::CompilesMGiza {
    method help() {
        " eman seed for compiling multicore giza"
    }
    
    method init(){
    
    }

    method prepare() {
    }

    method run() {
        $self->mgiza();
    }
}

1;
