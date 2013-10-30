use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::CompilesGiza with EmanSeed {

    method giza() {
        my $bc = $self->default_bash_context->copy;
        $self->safeSystem('tar xzf ../../src/giza-pp.tgz', e=>'giza-pp missing');
        $bc->add_prefix("cd giza-pp");
        $self->safeSystem ('patch -p1 < ../../../src/giza-pp.patch-against-binsearch', bc=>$bc);
        $bc->add_prefix("cd GIZA++-v2");
        
        $self->safeSystem("make -j4", bc=>$bc);
        $self->safeSystem("make -j4 snt2cooc.out", bc=>$bc);
        $bc->add_prefix("cd ../mkcls-v2");
        $self->safeSystem("make -j4", bc=>$bc);
        

        $self->safeSystem("mkdir -p bin"); 
        for my $d qw(../giza-pp/GIZA++-v2/GIZA++ 
               ../giza-pp/GIZA++-v2/snt2cooc.out 
               ../giza-pp/mkcls-v2/mkcls) {
            $self->safeSystem("ln -s $d bin/");
        }
    }

}

1;
