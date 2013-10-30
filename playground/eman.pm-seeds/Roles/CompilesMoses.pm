use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::CompilesMoses with EmanSeed {
    use HasDefvar;

    has_defvar 'SRILMSTEP'=>(default=>'', help=>'where is SRILM compiled, or empty');
    has_defvar 'IRSTLMSTEP'=>(default=>'', help=>'where is IRSTLM compiled, or empty');
    has_defvar 'MOSESBRANCH'=>(default=>'', help=>'check out a custom branch of Moses');
    has_defvar 'BJAMARGS'=>(default=>'', help=>'any extra arguments for the compilation of Moses');


    method moses() {
        if ($self->is_on_cluster) {
            print "\n!!!!!!!!\n\nWARNING: Moses does NOT compile on UFAL cluster ".
                    "because of incompatibility of old libboost and new gcc. ".
                    "Run this step with --no-sge option. \n\n!!!!!!!!!\n";
        }
        
        my $bc=$self->default_bash_context;
        $self->safeSystem("git clone https://github.com/moses-smt/mosesdecoder.git moses", bc=>$bc);
        $bc->add_prefix("cd moses");
        if ($self->MOSESBRANCH) {
            $self->selfSystem("git checkout ".$self->MOSESBRANCH, bc=>$bc);
        }
        my $srilmarg="";
        if ($self->SRILMSTEP) {
            $srilmarg =" --with-srilm=".$self->emanPath($self->SRILMSTEP)."/srilm ";
        }
        my $irstlmarg;
        if ($self->IRSTLMSTEP) {
            $irstlmarg=" --with-irstlm=".$self->emanPath($self->IRSTLMSTEP)."/install ";
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
1;
