use warnings;
use strict;
use MooseX::Declare;


#corpus has disadvantage that it is never run
#since corpman automatically uses the step "corpus" :)
class Seeds::Evaluator with (Roles::KnowsCorpman, Roles::KnowsMkcorpus, Roles::AccessesMosesBinaries) {
    use HasDefvar;

  has_defvar 'SCORERS'=>(default=>"-s BLEU -s PER -s TER -s CDER",
        help=>"scorers you want to use, you have to prefix each scorer with -s or --sctype.");
        
  has_defvar 'TRANSSTEP' =>(type=>'optstep', default=>'', 
    help=>"translation step, implies corpora and factor if given");
  has_defvar 'MOSESSTEP'=>(type=>'reqstep', inherit=>'TRANSSTEP',
        help=>"the step containing compiled tools");
  has_defvar 'TESTCORP'=>(inherit=>'TRANSSTEP', help=>"the translated corpus");
  has_defvar 'TRANSAUG'=>(inherit=>'TRANSSTEP:TOKAUG', help=>"translation language+factors");
  has_defvar 'REFAUGS'=>(inherit=>'TRANSSTEP:REFAUG',
        help=>"reference language+factors; use ':' to delimit multiple references");


    method help() {
        "Evaluates BLEU."
    }

    method init() {
        $self->add_refaugs();
    }

    method prepare() {
       if (!-x $self->evaluator) {
           $self->myDie("evaluator not present");
       }
    }
    
    method run() {
        $self->prepare_corp();        
        $self->make_references();#this could be left out but I don't like that big side effects :)
        $self->safeSystem($self->evaluator_command());
    }

    method add_refaugs() {
        for my $r (split(/:/, $self->REFAUGS)) {
            $self->init_corp_and_add_dep($self->TESTCORP, $r);
        }

    }

    method prepare_corp() {
        $self->mkcorpus_do($self->TESTCORP, $self->TRANSAUG, "translation");    
        $self->safeSystem("zcat corpus.translation.gz > corpus.translation");
    }

    has 'references'=>(isa=>'Int', is=>'rw');
    method make_references() {
        my$i=0;
        for my $r (split(/:/, $self->REFAUGS)) {
            $self->mkcorpus_do($self->TESTCORP, $r, "reference.$i");
            $self->safeSystem("zcat corpus.reference.$i.gz > corpus.reference.$i");
            $i++;
        }
        $self->references($i-1);
    }

    method references_string() {
        if (!$self->references) {
            $self->make_references();
        }
        join (",", map {"corpus.reference.$_"} (0..$self->references));
    }

    method evaluator_command() {
        return $self->evaluator." ".
            $self->SCORERS ." ".
            "--reference ".$self->references_string." ".
            "--candidate corpus.translation ".
            " --bootstrap 1000 ".
            " --rseed 1234 ".
            " | tee  scores ";
       
    }
} 
