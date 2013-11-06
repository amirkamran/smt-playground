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

    method gizawrapper() {
        my $r = $self->scriptsDir."/gizawrapper.pl";
        if (!-x $r) {
            $self->myDie( "gizawrapper not found: ".$r);
        }
        return $r;
    }
     

    method giza_command(Str $alisyms, Str $source, Str $target, Str $result) {

        return $self->gizawrapper.
              " $source $target ".
              "--lfactors=0 --rfactors=0 ".
              "--tempdir=".$self->get_temp.
              $self->giza_info_for_wrapper.
              "--dirsym=".$alisyms.
              " --drop-bad-lines ".
              " | gzip -c > $result";
    }

    method giza_info_for_wrapper() {
        if ($self->GIZASTEP =~ "mgiza") {
            return " --mgizadir=".$self->giza_dir."/bin --mgizacores=".$self->EMAN_CORES." ";
        } else {
            return  " --bindir=".$self->giza_dir."/bin  ";
        }
    }
}

1;
