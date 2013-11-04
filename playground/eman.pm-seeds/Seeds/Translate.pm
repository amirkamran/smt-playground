use warnings;
use strict;
use MooseX::Declare;

#note: I have decided not to use these two defvars
#because they are not used anywhere I can find
#DETOKAUG="$OUTLANG+$DETOKFACT" eman defvar DETOKAUG
#OUTALIAUG="$OUTLANG+$ALIFACT" eman defvar OUTALIAUG

                      #RunsDecoder inherits AccessesMosesBinaries
class Seeds::Translate with (Roles::SSD, Roles::RunsDecoder, Roles::KnowsMkcorpus, Roles::KnowsCorpman) {
  use HasDefvar;

   

  has_defvar 'MERTSTEP'=>(type=>'reqstep', help=>"step containing configuration file for Moses");
  
  #overloading the one in AccessesMosesBinaries
  has_defvar 'MOSESSTEP'=>(type=>'reqstep', inherit=>'MERTSTEP',
        help=>"the step containing compiled tools; inherited from MERTSTEP");
        
  has_defvar 'TESTCORP'=> (help=>'the corpus to translate');
  has_defvar 'SRCAUG'=> (inherit=>'MERTSTEP', help=>"language+factors to translate");
  has_defvar 'REFAUG'=> (inherit=>'MERTSTEP',
    help=>"language that will be created by translating; factor is 'untok'");
  has_defvar 'ITER'=>(default=>'',
            help=>"which MERT iteration weights to use; default is the final set");
            
  #overloads Roles::RunsTranslate because of the eman inheritance
  has_defvar 'SEARCH'=>(default=>'cube',help=>'the search type (beam or cube)', inherit=>'MERTSTEP');
  has_defvar 'STACK'=>(default=>'', help=>'stacksize for beam search', inherit=>'MERTSTEP');
    has_defvar 'MOSESFLAGS'=>(default=>'', help=>'further flags for moses, NOT including thread number', 
        inherit=>'MERTSTEP');
    has_defvar 'GRIDFLAGS'=>(default=>'', help=>'further flags for qsub, NOT including the number of threads', 
        inherit=>'MERTSTEP');
    has_defvar 'MOSESTHREADS'=>(default=>3, 
        help=>'how many threads does moses use; if JOBS=0 or not run on cluster, EMAN_CORES is used instead', 
        inherit=>'MERTSTEP');
  
  #overloads Roles::SSD
  has_defvar 'SSD'=>(default=>'', help=>'the path to some SSD scratch disk for filtered tables',inherit=>'MERTSTEP');
  has_defvar 'DELETE_FILTERED_MODEL'=>( default=>'no', help=>'set to yes to cleanup after success, very much suggested local disks (SSD points to a local disk)', inherit=>'MERTSTEP');

  has_defvar 'TOKAUG'=>(help=>'translation language+factors. is created automatically.', default=>'');

    method help() {
     "translates the given corpus";
    }

    method init() {
        $self->load_src_corp();  
        $self->create_tokaug();
        $self->promise_res_corp();
    }


 
   method prepare(){}

    method run() {
        $self->prepare_src_corpus();
        $self->prepare_moses_ini();
        $self->filter_for_eval();
        $self->safeSystem($self->translate_command, e=>"Failed to translate");
        $self->cleanup_alignment();
        $self->summarize_details();
        $self->detokenize();
        $self->register_corp_afterwards();
        $self->cleanup_filter();
    } 

    

    method prepare_src_corpus() {
        $self->mkcorpus_do($self->TESTCORP, $self->SRCAUG, "src");
        $self->safeSystem("gunzip -c corpus.src.gz > corpus.src");
     }
    
    method detokenize() {
        $self->safeSystem("zcat translated.gz ".
            " | ".$self->moses_scripts_dir."/tokenizer/detokenizer.perl -u -l ".
            $self->targetlan_for_detoken.
            " | gzip -c > translated.untok.gz ",e=>"Failed to detokenize");
    
    }


    method summarize_details() {
        $self->safeSystem('gzip details');
        $self->safeSystem('zcat details.gz | '.$self->scriptsDir.'/summarize-moses-details.pl '.
                ' > details.summary');
        
    }


    method cleanup_alignment() {
        
        $self->safeSystem('sed -e \'s/^ *//\' -e \'s/ *$//\' -i alignment');
        $self->safeSystem('gzip alignment');

    }

    method translate_command() {
        return $self->moses_maybe_parallel.
                " -input-file ./corpus.src ".
                " -alignment-output-file ./alignment ".
                " -translation-details ./details ".
                " -config ./filtered-for-eval/moses.ini ".
                " | sed 's/^ *//;s/ *\\\$//' ".
                " | gzip -c ".
                " > translated.gz ";
    }

    method filter_for_eval() {
        $self->create_dir_and_filter("filtered-for-eval", "moses.abs.ini", "corpus.src");
    }

    has 'mertstepdir'=>(isa=>'Str', is=>'rw',default=>sub {
        my $self=shift; 
        return $self->emanPath($self->MERTSTEP);
    }, lazy=>1);
    
    method prepare_moses_ini() {
        if (!-e "moses.ini") {
            $self->safeSystem($self->moses_scripts_dir."/training/clone_moses_model.pl "
                                        ." --symlink "
                                        .$self->mertstepdir."/moses.ini", e=>"Failed to clone the full model");
            $self->safeSystem($self->moses_scripts_dir."/ems/support/reuse-weights.perl ".
                                $self->mertstepdir."/mert-tuning/".$self->iterprefix."moses.ini ".
                                "< ./moses.ini > moses.mertweights.ini", e=>"Failed to apply weights from mert");
            $self->safeSystem($self->moses_scripts_dir."/training/absolutize_moses_model.pl ".
                                $self->mydir."/moses.mertweights.ini > moses.abs.ini", e=>"Failed to absolutize");
        }
    }

    method targetlan_for_detoken() {
        my $res = substr($self->REFAUG,0,2);
        my $bezelo = $self->safeSystem("echo test | ".$self->moses_scripts_dir."/tokenizer/detokenizer.perl ".
                                        "-u -l $res >/dev/null 2>&1", dodie=>0);
        if (!$bezelo) {
            print "Defaulting to 'en' as the targetlang for detokenizer.";
            $res="en";
        }
        return $res
    }


    method load_src_corp() {
        $self->init_corp_and_add_dep($self->TESTCORP, $self->SRCAUG);
    }


    method register_corp_afterwards() {
    
        $self->register_all_corpora($self->safeBacktick('zcat translated.untok.gz | wc -l'));
    }
    
    method promise_res_corp() {
        $self->register_all_corpora(-1);
    }

    method register_all_corpora(Int $lines) {
        my %what=(translated=>$self->tokfact(), 'translated.untok'=>'untok', alignment=>'ali');
        for my $k (keys %what) {
                $self->promise_corp(
                    filename=>"$k.gz",
                    column=>-1,
                    corpname=>$self->TESTCORP,
                    lang=>$self->outlang,
                    factors=>$what{$k},
                    count=>$lines,
                    #puvodne byla v translate seedu jakasi 0 na konci... asi nesmysl
                );
        }
    }

    method cleanup_filter() {
        if ($self->DELETE_FILTERED_MODEL eq "yes" ) {
            $self->delete_maybe_on_SSD("filtered-for-eval");
        }
    }

    method tokfact() {
          my @refaug = split (/\+/, $self->REFAUG);
          shift @refaug;
          return join ("+", @refaug);
    }

    method outlang(){
          my @refaug = split (/\+/, $self->REFAUG);
          my $res = shift @refaug;
          $res .= "_".$self->base;
          return $res;
     }


    method create_tokaug() {
        my $res = $self->outlang()."+".$self->tokfact();;
        $self->TOKAUG($res);
    }

    method iterprefix() {
        if ($self->ITER ne "") {
            return "run".($self->ITER+1).".";
        }
        return "";
    }

}
