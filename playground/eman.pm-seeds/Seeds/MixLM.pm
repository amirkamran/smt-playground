use warnings;
use strict;
use MooseX::Declare;

class Seeds::MixLM with (Roles::KnowsMkcorpus, Roles::AccessesMosesBinaries, Roles::AccessesSrilm) {
    use HasDefvar;
  
    #this is needed because other steps look at this variable
    has_defvar 'CORP'=> (help=>'the shortname of resulting corpus, is automatically generated', default=>'');

    has_defvar 'LMS'=>(help=>'colon-delimited list of lm steps', type=>'steplist');
    has_defvar 'HELDOUT'=>(help=>'the shortname of corpus');
    has_defvar 'PROMISEAUGMATCH'=>(default=>'no', help=>'yes to ignore difference in corpaugs');
    has_defvar 'ORDER'=> (help=>'the lm order' , firstinherit=>'LMS');
    has_defvar 'CORPAUG'=> (help=>'the language+factors for the lm. inherited from first LM.', firstinherit=>'LMS');

    #overloads the one in AccessesSrilm
    has_defvar 'SRILMSTEP'=> (
        firstinherit=>'LMS',
        help=>'where is srilm compiled'); 
   
    method help() {
        "eman seed for constructing an n-gram language model by mixing ".
        "several LMs for best perplexity on a heldout text";
    }
    
    has 'lmfiles'=>(isa=>'ArrayRef[Str]', is=>'rw');

    method init() {
        my @lms = split (/:/, $self->LMS);
        $self->check_orders_save_names(\@lms);
        $self->emanSaveTag("MIXLM:".$self->CORP."+".
                            $self->CORPAUG.".".$self->ORDER);
    } 
    
    method prepare() {
    }    
    
    method run() {
        $self->clone_heldout();
        $self->interpolate();
    }

    method interpolate(){
        my $filelist = $self->get_filelist();

        $self->safeSystem($self->moses_scripts_dir."/ems/support/interpolate-lm.perl ".
                "--tuning corpus.heldout ".
                "--name corpus.lm ".
                "--lm $filelist ".
                "--srilm=".$self->srilm_dir_686." ".
                "--tempdir=".$self->get_temp,
             e =>"Mixing models failed");
    
    }

    method clone_heldout() {
        $self->safeSystem($self->mkcorpus_command($self->HELDOUT, $self->CORPAUG, "heldout"));

        $self->safeSystem("zcat corpus.heldout.gz > corpus.heldout");
    }

    method check_orders_save_names(ArrayRef[Str] $lms) {
        my @files=();
        my @names=();
        for my $lmexp (@$lms) {
            my $lmdir=$self->emanPath($lmexp);
            my $thisorder=$self->emanGetVar($lmexp, "ORDER");
            my $thisaug=$self->emanGetVar($lmexp, "CORPAUG");
            my $thiscorp=$self->emanGetVar($lmexp,"CORP");
            push @names, $thiscorp;
            push @files, "$lmdir/corpus.lm";
            if ($thisorder != $self->ORDER) {
                $self->myDie("Mismatch in ORDER: Expected ".$self->ORDER.", $lmexp has $thisorder");
            }
            if ($self->PROMISEAUGMATCH eq "yes" and $thisaug ne $self->CORPAUG) {
                $self->myDie("Mismatch in CORPAUG: Expected ".$self->CORPAUG.", $lmexp has $thisaug");
            }
        }
        my $namelist = join("++", @names);
        $self->lmfiles(\@files);
        $self->CORP($namelist);
    }

    


    method get_filelist() {
        return join (",", map {
            if (-e $_) {
                $_
            } elsif (-e $_.".gz") {
                $_.".gz"
            } else {
                $self->myDie("not found: $_")
            }
        } @{$self->lmfiles}); 
    }




}

1;
