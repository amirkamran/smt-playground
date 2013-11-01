use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

#both Translate and Mert use this...
role Roles::RunsDecoder with (Roles::AccessesMosesBinaries, Roles::HasJobsOnCluster) {

    has_defvar 'SEARCH'=>(default=>'cube',help=>'the search type (beam or cube)');
    has_defvar 'MOSESFLAGS'=>(default=>'', help=>'further flags for moses, NOT including thread number');
    has_defvar 'GRIDFLAGS'=>(default=>'', help=>'further flags for qsub, NOT including the number of threads');
    has_defvar 'MOSESTHREADS'=>(default=>3, help=>'how many threads does moses use; if JOBS=0 or not run on cluster, EMAN_CORES is used instead');
    has_defvar 'STACK'=>(default=>'', help=>'stacksize for beam search');

    before init() {
        if ($self->MOSESFLAGS =~/\-th/) {
            $self->myDie("Do not specify number of moses threads in MOSESFLAGS, use MOSESTHREADS var instead.");
        }
        if ($self->GRIDFLAGS =~/pe smp/) {
            $self->myDie("Do not specify number of moses threads in GRIDFLAGS, use MOSESTHREADS var instead.");
        }    
    }

    before run() {
        if (!-e "moses") {
            $self->wiseLn($self->moses_cmd, "./moses");
        }
    }

    method searchflags(){
        if ($self->SEARCH eq "beam") {
            return "-search-algorithm 0";
        }
        if ($self->SEARCH eq "cube") {
            return "-search-algorithm 1";
        }
        self->myDie("Bad search algorithm: ".$self->SEARCH);
    }
    
    method gridflags_additional() {
        return " -pe smp ".$self->MOSESTHREADS." ";
    }

    method real_gridflags(Int :$cores=-1){
        if ($cores==-1) {
            $cores=$self->MOSESTHREADS;
        }
        my $res = $self->GRIDFLAGS;
        if ($self->GRIDFLAGS =~ /-p +-?[0-9]+/) {
            $res .= ." -cwd -S /bin/bash";
        } else {
            $res .= " -p -100 -cwd -S /bin/bash";
        }
        $res .=  " -pe smp $cores ";
        return $res;
    }

    method mosesflags_additional() {
        my $r="";
        if ($self->MOSESFLAGS !~ /-dl/) {
            $r.=" -dl 6 ";
        }
        if ($self->STACK) {
            $r.=" -s ";
            $r.=$self->STACK;
        }
 

       if (!$self->real_jobs) {
            if ($self->EMAN_CORES) {
                print "!!!!\nrunning with JOBS=0 or not on cluster; ignoring MOSESTHREADS, using EMAN_CORES\n";
                $r.=" -threads ";

                $r .= $self->EMAN_CORES;
            }
        } else {
            $r.=" -threads ";
            $r.=$self->MOSESTHREADS;
        }

        return $r;
    }
  
    method moses_maybe_parallel() {
        if (!$self->real_jobs) {
            return "./moses ".$self->decoder_flags();
        } else {
            return $self->_moses_parallel." ".$self->mosesgridargs." -decoder-parameters ' ".$self->decoder_flags." ' ".
                    " -feed-decoder-via-stdin -decoder ./moses";
        }
    }

    method _moses_parallel() {
        return $self->moses_scripts_dir."/generic/moses_parallel.pl";
    }

    method decoder_flags() {
        return $self->MOSESFLAGS.$self->mosesflags_additional." ".
                $self->searchflags
    }
    
    #this should probably be only in Mert.pm, but yeah, it is here too
    method mertgridargs() {
        if (!$self->real_jobs){
            return ""            
        } else {
            #mert takes only one core
            return "--jobs=".$self->real_jobs." --queue-flags=' ".$self->real_gridflags(cores=>1)." ' ";             
        }
    }
    
    method mosesgridargs(){
        if (!$self->real_jobs){
            return ""            
        } else {
            return "--jobs=".$self->real_jobs." --queue-flags=' ".$self->real_gridflags." ' ";             
        }
    }

}
