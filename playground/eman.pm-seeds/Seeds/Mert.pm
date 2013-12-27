use warnings;
use strict;
use MooseX::Declare;

                        #RunsDecoder inherits AccessesMosesBinaries and HasJobsOnCluster
class Seeds::Mert with (Roles::RunsDecoder, Roles::SSD, Roles::KnowsCorpman) {
    use HasDefvar;
    
    has_defvar 'MODELSTEP'=>(type=>'reqstep', help=>'where is the model (moses.ini) incl. all files');
    has_defvar 'DEVCORP'=>(help=>'the corpus for tuning; use colon to delimit more corpora (the source side will be taken from the first one only)');
    has_defvar 'SRCAUG'=>(inherit=>'MODELSTEP',help=>'the source lang+factors');
    has_defvar 'REFAUG'=>(inherit=>'MODELSTEP:TGTAUG', help=>'the target (reference) lang+factors');
  
    has_defvar 'MERTFLAGS'=>(default=>'', help=>'further flags for mert.pl');
    has_defvar 'TAGPREF'=>(default=>'', help=>'eman tag prefix');
    has_defvar 'MERTPRG'=>(default=>'mert', help=>'mert/zmert/pro (not quite tested)');
    has_defvar 'ZMERTMETRIC'=>(default=>'', help=>'for zmert: SemPOS, SemPOS_BLEU, BLEU, TER, TER-BLEU');
    has_defvar 'ZMERTSEMPOSSOURCE'=>(default=>'', help=>'for zmert: factors:1,2 (factors:1,2,3 for SemPOS_BLEU) or tmt');
    has_defvar 'ZMERTSEMPOSBLEUWEIGHTS'=>(default=>'', help=>'for zmert --semposbleu-weights, e.g. 1:1');
    has_defvar 'ZMERTFLAGS'=>(default=>'', help=>'zmert flags');
    has_defvar 'TREEXSTEP'=>(default=>'', help=>'for zmert SemPOS tmt (used to be TMT_ROOT; untested)');
    
    #overloading
    has_defvar 'MOSESSTEP'=>(inherit=>'MODELSTEP', help=>'where are moses scripts and binaries');
    
 
    has_defvar 'DELETE_FILTERED_MODEL'=>(default=>'no', help=>'set to yes to cleanup after success, very much suggested local disks (SSD points to a local disk)');

   
    method help() {
        "eman seed for running mert on a moses model"
    }

    method init() {
        $self->safeSystem("echo ".$self->MODELSTEP." > info.modelexp");
        $self->addCorpDeps();
    }

    method prepare() {
        $self->createTuningCorps();
    }

    method run() {
        $self->clone_moses_ini();
        $self->absolutize_moses();

        $self->filter_for_mert();
        $self->do_main_mert();
        $self->weights_sanity_check();
        $self->cleanup_mert();
    }

    method absolutize_moses() {
        $self->safeSystem($self->moses_scripts_dir."/training/absolutize_moses_model.pl `pwd`/moses.ini > moses.abs.ini", e=> "Absolutize failed");
    }

    method clone_moses_ini() {
        if (!-e "moses.ini") {
            $self->safeSystem($self->moses_scripts_dir."/training/clone_moses_model.pl --symlink ".
                                    $self->emanPath($self->MODELSTEP)."/model/moses.ini");
        }
    }

    method filter_for_mert() {
        $self->create_dir_and_filter("filtered-for-mert", "moses.abs.ini", "tuning.in");
    }


    method do_main_mert() {
        $self->safeSystem($self->mert_command,  e=>"Mert failed");
    }

    method cleanup_mert() {
         
        if ($self->DELETE_FILTERED_MODEL eq "yes" ) {
            $self->delete_maybe_on_SSD("filtered-for-mert");
        }

    }



    method addCorpDeps () {
        my @corpora = split (/:/, $self->DEVCORP);

        my $first=$corpora[0];
        $self->init_corp_and_add_dep($first, $self->SRCAUG);
        for (@corpora){
            $self->init_corp_and_add_dep($_, $self->REFAUG);
        }
    }

    # create local copies of the corpora
    method createTuningCorps() {
        my @corpora = split (/:/, $self->DEVCORP);
        $self->dump_corp(corpname=>$corpora[0], aug=>$self->SRCAUG, where=>"tuning.in");
        
        my $size = $self->safeBacktick("wc -l tuning.in | cut -f 1 -d ' '");
        if (!$size) {
           $self->myDie("empty tuning.in"); 
        }
        
        my $i=0;
        for my $devcorp (@corpora){
            $self->dump_corp(corpname=>$devcorp, aug=>$self->REFAUG, where=>"tuning.ref.$i");
            
            if ($size != $self->safeBacktick("wc -l tuning.ref.$i| cut -f 1 -d ' '")) {
                $self->myDie("Mismatching number of lines in tuning.ref.$i taken from $devcorp/".$self->REFAUG)
            }
            $i++;
        }
    
    }

    
     

    method mertmoses() {
        return $self->moses_scripts_dir."/training/mert-moses.pl"
    }
    method zmertmoses() {
        return $self->moses_scripts_dir."/training/zmert-moses.pl"
    }


    

    method decoder_flags_string() {
         return '--decoder-flags="'.$self->decoder_flags().'"'; 
    }

    method weights_sanity_check() {
        my $all_weights = $self->safeBacktick("cat mert-tuning/weights.txt");
        my @nums = split (/\s+/, $all_weights);
        my @non_zeroes = grep {$_!=0} @nums;
        if (scalar @non_zeroes == 0) {
            $self->myDie("Weights are all zeroes. Probably mismatched model and tuning corpus; check mert-tuning/run1.out and tuning.ref");
        }
    }
    
    has 'mert_command' => (is=>'ro', isa=>'Str', lazy=>1, default=>sub {
        my $self=shift;
        if ($self->MERTPRG eq "zmert") {
            return (join " ", $self->zmertmoses, 
                        "--working-dir=".$self->mydir."/mert-tuning",
                        $self->mydir."/tuning.in",
                        $self->mydir."/tuning.ref.",
                        $self->mydir."/moses",
                        $self->mydir."moses.abs.ini",

                        "--mertdir=".$self->mstep_dir."/../../moses/zmert/",
                        '--metric="'.$self->ZMERTMETRIC.'"',
                        $self->ZMERTFLAGS,
                        $self->mertgridargs,
                        $self->decoder_flags_string
                     );
       } elsif ($self->MERTPRG eq "mert") {
            return (join " ", $self->mertmoses,
                "--working-dir=".$self->mydir."/mert-tuning",
                "--no-filter-phrase-table",
                $self->mydir."/tuning.in",
                $self->mydir."/tuning.ref.",
                $self->mydir."/moses",
                $self->mydir."/filtered-for-mert/moses.ini",
                $self->mertgridargs,
                $self->MERTFLAGS,
                $self->decoder_flags_string
           );

       }
        $self->myDie("wrong mertprg ".$self->MERTPRG);
    });
}

1;
