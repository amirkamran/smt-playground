use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::KnowsMkcorpus with (EmanSeed, Roles::KnowsCorpman) {

    method mkcorpus_initial_preparations(Str $corpus, Str $short, Str $dir, Str $type, Str $aliaug) {
        my $corpname=$corpus."/".$aliaug;
        
        my $fn = "$dir/$type.$short.gz";
        
        $self->safeSystem("touch $fn", mute=>1, e=>"Cannot write to $fn");
        
        if (-e $fn) {
            $self->safeSystem("rm -f $fn", mute=>1);
        }
        return ($corpname, $fn);
    }

    method mkcorpus_prepare(Str $corpname) {
        $self->safeSystem($self->_corpmanCommand(["--factorindex",
                                                 "--wait",
                                                 $corpname]),e=>"Failed to prepare $corpname");

    }

    method mkcorpus_corpman_cmd(Str $corpname) {
        return $self->safeBacktick($self->_corpmanCommand(['--factorindex',
                                                                   '--cmd',
                                                                   $corpname]));
   }
    
    method step_file_info(Str $corpname) {
        my %res;
        my @step_file_col= split(/\s+/, $self->safeBacktick($self->_corpmanCommand(["--factorindex", $corpname])));
        my $step_file = $self->emanPath($step_file_col[0]);
        $step_file.="/".$step_file_col[1];
        return ($step_file, $step_file_col[2], $step_file_col[3]);
    }
    
    method mkcorpus_do(Str $corpus, Str $aliaug, Str $short, Str :$dir=".", Str :$type="corpus") {
        $self->safeSystem($self->mkcorpus_command($corpus, $aliaug, $short, dir=>$dir, type=>$type));
    }

    method mkcorpus_command(Str $corpus, Str $aliaug, Str $short, Str :$dir=".", Str :$type="corpus") {
        
        my ($corpname, $fn) =$self-> mkcorpus_initial_preparations($corpus, $short, $dir, $type, $aliaug);
        $self->mkcorpus_prepare($corpname);
        
        my ($step_file, $columns, $factors) = $self->step_file_info($corpname);

        my $cmd= $self->mkcorpus_corpman_cmd($corpname);
        
        # There are additional factors that must be filtered out.
        if ($factors != -1 ) {
            return "$cmd | ".$self->scriptsDir."/reduce_factors.pl $factors | gzip -c > $fn";
        }
        
        # Source corpus contains just one column.
        if ( $columns == -1 ) {
                return $self->wiseLn($step_file, $fn, justCommand=>1);
       } else {
                return "$cmd | gzip -c > $fn";
       }
   }

}

1;
