use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::CompilesMGiza with EmanSeed {

    method mgiza() {
        if ($self->is_on_cluster) {
            print "\n!!!!!!!!\n\nWARNING: MGiza does NOT compile on UFAL cluster ".
                    "because of incompatibility of old libboost and new gcc. ".
                    "Run this step with --no-sge option. \n\n!!!!!!!!!\n";
        }
        

        my $bc = $self->default_bash_context->copy;
        $self->safeSystem('tar xzf ../../src/mgizapp-0.7.3.tgz', e=>'mgiza missing');
        $bc->add_prefix("cd mgizapp");
        $self->safeSystem(q(sed -i 's/1\.41/1\.40/' CMakeLists.txt), bc=>$bc);
        
        $self->safeSystem ('cmake .', bc=>$bc);
        $self->safeSystem("make", bc=>$bc);

        $self->safeSystem("mkdir -p bin"); 
        for my $d qw(
                    ../mgizapp/bin/mgiza 
                    ../mgizapp/bin/snt2cooc 
                    ../mgizapp/bin/mkcls
                    ../mgizapp/bin/symal
                    ../mgizapp/scripts/merge_alignment.py) {
            $self->safeSystem("ln -s $d bin/");
        }
    }

}

1;
