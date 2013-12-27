use warnings;
use strict;
use MooseX::Declare;

class Seeds::MosesGiza with (Roles::CompilesMoses, Roles::CompilesGiza) {
    method help() {
        " eman seed for compiling moses and giza"
    }
    method init(){
    }

    method prepare() {
    }

    method run() {
        $self->giza();
        $self->moses();
    }
}

1;
