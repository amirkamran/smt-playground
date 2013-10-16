use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role HasMoses with EmanSeed {
    use HasDefvar;

    has_defvar 'SRILMSTEP'=>(attrs=>q(default=''), help=>'where is SRILM compiled, or empty');
    has_defvar 'IRSTLMSTEP'=>(attrs=>q(default=''), help=>'where is IRSTLM compiled, or empty');
    has_defvar 'MOSESBRANCH'=>(attrs=>q(default=''), help=>'check out a custom branch of Moses');
    has_defvar 'BJAMARGS'=>(attrs=>q(default=''), help=>'any extra arguments for the compilation of Moses');


    method moses() {
        my $bc=$self->default_bash_context->copy;
        $self->safeSystem("git clone https://github.com/moses-smt/mosesdecoder.git moses", bc=>$bc);
        $bc->add_prefix("cd moses");
        if ($self->MOSESBRANCH) {
            $self->selfSystem("git checkout ".$self->MOSESBRANCH, bc=>$bc);
        }
        my $srilmarg="";
        if ($self->SRILMSTEP) {
            $srilmarg =" --with-srilm=`eman path ".$self->SRILMSTEP."`/srilm ";
        }
        my $irstlmarg;
        if ($self->IRSTLMSTEP) {
            $irstlmarg=" --with-irstlm=`eman path ".$self->IRSTLMSTEP."`/install ";
        }
        my $bjam = " --max-kenlm-order=8 ".$self->BJAMARGS;
        my $toRun = "./bjam -j4 --with-giza=".$self->mydir."/bin ".
            join(" ",$srilmarg, $irstlmarg, $bjam);
        $self->safeSystem($toRun, e=>"Build failed", bc=>$bc);
        for my $d qw(../moses/bin/moses 
                     ../moses/bin/moses_chart 
                     ../moses/bin/symal){
            $self->safeSystem("ln -s $d bin/");
        }
    }
}

class Moses with HasMoses {
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
