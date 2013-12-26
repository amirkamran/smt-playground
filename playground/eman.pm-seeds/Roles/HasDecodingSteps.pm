use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::HasDecodingSteps with EmanSeed {
    use HasDefvar;

    has_defvar 'DECODINGSTEPS'=>(
        help=>"specification of decoding steps, e.g. t0a1-0+t1-1");

    has 'decrypted_steps' => (is=>'rw', isa=>'Str',lazy=>1,default=>sub{
        my $self=shift;
        my $decrypt = $self->playground."/tools/decrypt_mapping_steps_for_training.pl";
        $self->myDie("Missing or not executable $decrypt") if (!-x $decrypt);
        my $r = $self->safeBacktick('eval '.$decrypt."  ".$self->DECODINGSTEPS);
        if (!$r) {
            $self->myDie("Failed to decrypt decodingsteps ".$self->DECODINGSTEPS);
        }
        return $r;
    });

};


1
