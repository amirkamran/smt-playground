use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;
use Moses;
use Giza;


class MosesGiza with (HasMoses, HasGiza) {
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
