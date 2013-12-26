use warnings;
use strict;
use MooseX::Declare;


class Seeds::Srilm with EmanSeed {
    method help() {
        " eman seed for compiling srilm"
    }
    
    method init(){
    
    }

    method prepare() {
    }

    method run() {
        my $SRILM_MACHTYPE;
        if ($self->safeBacktick("uname -m") eq "x86_64") {
            $SRILM_MACHTYPE="i686-m64"
        } else {
            $SRILM_MACHTYPE="i686-gcc4"
        }

        $self->safeSystem("mkdir srilm");

        my $bc = $self->default_bash_context->copy;
        $bc->add_prefix("cd srilm");
        $self->safeSystem("tar xzf ../../../src/srilm.tgz", bc=>$bc);
        
        $bc->add_prefix('export SRILM=$(pwd)');
        $bc->add_prefix('export NO_TCL=X');


        $self->safeSystem("make -j4 MACHINE_TYPE=$SRILM_MACHTYPE World", e=> "SRILM failed", bc=>$bc);
        
        for my $endname qw(m64 gcc4) {
            for my $dirname qw(lib bin) {
                if (-e "srilm/$dirname/i686-$endname") {
                    $self->safeSystem("ln -s i686-$endname srilm/$dirname/i686");
                }
            }
        }
        if (! -e "srilm/bin/i686/ngram-count") {
            $self->myDie("ngram-count was not compiled. See ".$self->pwd."/srilm/log* for e.g. this error: '/usr/bin/ld: cannot find -ltcl'");            
        }

        $self->safeSystem("pwd > ../srilm.path", bc=>$bc); #this should not need bash, but who cares
    }
}

1;
