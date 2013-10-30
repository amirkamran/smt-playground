use warnings;
use strict;
use MooseX::Declare;

class Seeds::Moses with Roles::CompilesMoses {
    method help() {
        " eman seed for compiling moses"
    }
    method init(){
    
    }
    method prepare() {
    }

    method run() {
        $self->moses();
    }
}

1;
