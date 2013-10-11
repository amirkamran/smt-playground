use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

class MosesGiza with EmanSeed {
    use HasDefvar;


    has_defvar 'SRILMSTEP'=>(attrs=>q(default=''), help=>'where is SRILM compiled, or empty');
    has_defvar 'IRSTLMSTEP'=>(attrs=>q(default=''), help=>'where is IRSTLM compiled, or empty');
    has_defvar 'MOSESBRANCH'=>(attrs=>q(default=''), help=>'check out a custom branch of Moses');
    has_defvar 'BJAMARGS'=>(attrs=>q(default=''), help=>'any extra arguments for the compilation of Moses');

    method help() {
        " eman seed for compiling moses"
    }
    method init(){
    
    }

    method prepare() {
    }

    method giza(BashContext $bc_or) {
        my $bc = $bc_or->copy;
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

    method moses(BashContext $bc_or) {
        my $bc=$bc_or->copy;
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

    method run() {
        $|=1;
        my $bc = $self->default_bash_context->copy;

        $self->giza($bc);
        $self->moses($bc);
    }
}

1;
