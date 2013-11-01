use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::SSD with EmanSeed {

    has_defvar 'SSD'=>(default=>'', help=>'the path to some SSD scratch disk for filtered tables');
   
    before run() {
        if (!-d $self->SSD) {
            $self->myDie($self->SSD." is not a directory.");
        }
        if (!-w $self->SSD) {
            $self->myDie($self->SSD." is not writable.");
        }
    }

    method base() {
        return $self->safeBacktick("basename ".$self->mydir);
    }

    method delete_maybe_on_SSD(Str $name) {
        
        if (!$self->SSD) {
            $self->safeSystem("rm -rf $name");
        } else {
            my $new = $self->SSD."/".$self->base."/$name";
            $self->safeSystem("rm -rf $name");
            $self->safeSystem("rmdir $new");
        }
        
    }

    method create_maybe_on_SSD(Str $name) {
        
        if (!$self->SSD) {
            $self->safeSystem("mkdir -p $name");
            return $name;
        } else {
            my $new = $self->SSD."/".$self->base."/$name";
            $self->safeSystem("mkdir -p $new");
            $self->safeSystem("ln -s $filteroutdir ./");
            return $new;
        }
        
    }

}
