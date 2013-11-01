use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::AccessesGiza with EmanSeed {
    use HasDefvar;

    has_defvar 'GIZASTEP'=> (type=>'reqstep', help=>'where is GIZA/mGIZA and symal compiled'); 


    has 'giza_dir' =>(isa=>'Str', is=>'rw', lazy=>1, default=>sub{
        my $self=shift;
        return $self->emanPath($self->GIZASTEP)
    });

        
    
    method giza_info_for_wrapper() {
        if ($self->GIZASTEP =~ "mgiza") {
            return " --mgizadir=".$self->giza_dir."/bin --mgizacores=".$self->EMAN_CORES." ";
        } else {
            return  " --bindir=".$self->giza_dir."/bin  ";
        }
    }
}

1;
