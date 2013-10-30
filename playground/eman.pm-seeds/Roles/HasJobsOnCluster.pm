use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::HasJobsOnCluster with EmanSeed {
    use HasDefvar;

    has_defvar 'JOBS' =>( help=>'how many jobs to submit, 0 to disable SGE', default=>15);
    method real_jobs() {
        if (!$self->is_on_cluster) {
            return 0;
        }
        return $self->JOBS;
    }

}


1;
