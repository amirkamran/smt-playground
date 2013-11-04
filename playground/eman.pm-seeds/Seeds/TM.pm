use warnings;
use strict;
use MooseX::Declare;

class Seeds::TM with (Roles::KnowsMkcorpus, Roles::AccessesMosesBinaries, Roles::HasDecodingSteps, Roles::KnowsCorpman) {
    use HasDefvar;
  
    has_defvar 'ALISTEP'=>(default=>'', type=>'optstep',
            help=>"the step where alignment was constructed, implied by ALICORP+ALISYM+ALILABEL");
    has_defvar 'SRCCORP'=>(inherit=>'ALISTEP:CORPUS', 
            help=>"source corpus name");
    has_defvar 'TGTCORP'=>(same_as=>'SRCCORP', 
            help=>"target corpus name, can be omitted if equal to SRCCORP");
    has_defvar 'SRCAUG'=>(
       help=>"the string describing lang+factors of src corpus");
    has_defvar 'TGTAUG'=>(
        help=>"the string describing lang+factors of tgt corpus");
    has_defvar 'ALICORP'=>(same_as=>'SRCCORP', 
        help=>"alignment corpus name, can be omitted if equal to SRCCORP");
    has_defvar 'ALISYM'=> (default=>'gdfa', 
        help=>'which alignment to use for the translation model');
    has_defvar 'ALILABEL'=>(inherit=>'ALISTEP',
        help=>"the custom label as given when creating the alignment" );
    has_defvar 'ALIORREVALI'=>(default=>'ali',
        help=>"set to 'ali' for standard usecase but to 'revali' for revgdfa etc.");
    has_defvar 'TRAININGFLAGS'=>(default=>'', 
        help=>"flags for train-factored-phrase-model.perl");
    has_defvar 'THRESHOLD'=>(default=>'', 
        help=>"a+e, a-e of a number (see moses/sigtest-filter)" );
    has_defvar 'NBESTOOV'=>(default=>'', 
       help=>"output n-best lexical entries in reduce-oov.pl(0=output all)");
    has_defvar 'CUTOFF'=>(default=>0, 
        help=>"phrase-table cutoff" );

    method help() {
        "Prepare moses translation model, i.e. extract phrases" 
    }


    method init() {
        $self->redefine_alistep();
    }

    method prepare() {
        $self->check_alistep("CORPUS", $self->SRCCORP);
        $self->check_alistep("ALILABEL", $self->ALILABEL);
    }

    method run() {
        $self->safeSystem("rm -rf corpus* alignment* model*");
        
        $self->safeSystem("mkdir corpus");
        $self->safeSystem("mkdir model");
        $self->mkcorpora();
        $self->make_temp();
        $self->really_make_tm();
        $self->check_phrase_count();
    }

    method redefine_alistep() {
       if (!$self->ALISTEP) {
            $self->ALISTEP(
                $self->init_corp_and_add_dep($self->ALICORP,$self->ALISYM."+".$self->ALILABEL."/ali");
            ); 
       } 
       $self->check_decoding_steps_for_comma( );
    }

    method check_decoding_steps_for_comma() {
        if ($self->DECODINGSTEPS =~ /,/) {
            $self->myDie("DECODINGSTEPS (".$self->DECODINGSTEPS.") contains a comma! Use 'a' instead, e.g. 0a1-0+1-1");
        }
    }

    method check_alistep(Str $what, Str $should_be) {
        my $known = $self->emanGetVar($self->ALISTEP, $what);
        $known =~ s/^"(.*)"$/$1/;
        if ($known ne $should_be) {
            if ($known ne "") {
                $self->myDie("Nonmatching alistep: different $what: ".$known." vs ".$should_be);
            }
        }
    }




    method maybe_reverse_alignment() {
        if ($self->ALIORREVALI eq "revali") {
             $self->safeSystem("zcat alignment.orig.gz | ".$self->scriptsDir."/reverse_alignment.pl | gzip -c ".
                        "> alignment.custom.gz");
        } else {
            $self->safeSystem("ln -s alignment.orig.gz alignment.custom.gz");
        }
    }

    method check_lengths() {
       my $alilen=$self->safeBacktick('zcat alignment.custom.gz | wc -l');
       my $srclen=$self->safeBacktick('zcat corpus/corpus.src.gz | wc -l');
       my $tgtlen=$self->safeBacktick('zcat corpus/corpus.tgt.gz | wc -l');
       if ($alilen != $srclen or  $alilen != $tgtlen ) {
            $self->myDie("Incompatible corpus lengths:\n".
                        "$alilen  alignment.custom.gz\n".
                        "$srclen  corpus.src.gz\n".
                        "$tgtlen  corpus.tgt.gz");
       }
 
    }

    #I am using "step_tempdir" to avoid confusion with
    #the one from EmanSeed
    has 'step_tempdir' => (isa=>'Str', is=>'rw');

    method make_temp {
        $self->step_tempdir ($self->safeBacktick("mktemp -d ".$self->get_temp."/exp.model.XXXXXX"));
        $self->safeSystem(q(rsync -avz --exclude 'log*' --exclude '*.hardlink' * ).$self->step_tempdir."/");
        print "COPIED, used disk space:\n";
        $self->safeSystem("df ".$self->step_tempdir, mute=>1);
    }
    

    method mkcorpora(){
        $self->mkcorpus_do($self->SRCCORP, $self->SRCAUG, "src", dir=>"corpus");
        $self->mkcorpus_do($self->TGTCORP, $self->TGTAUG, "tgt", dir=>"corpus");
        $self->mkcorpus_do($self->ALICORP, 
                                        $self->ALISYM."-".$self->ALILABEL."+ali", "orig", dir=>".", type=>"alignment");
        $self->maybe_reverse_alignment();
        $self->check_lengths();
                
    }

    method train_model(Int $first_step, Int $last_step) {
        return $self->safeSystem($self->moses_scripts_dir."/training/train-model.perl ".
                                    "--force-factored-filenames ".
                                    "--first-step $first_step --last-step $last_step ".
                                    "--root-dir ".$self->step_tempdir." ".
                                    "--alignment-file=".$self->step_tempdir."/alignment ".
                                    "--alignment=custom ".
                                    "--corpus=".$self->step_tempdir."/corpus/corpus ".
                                    "--f src --e tgt ".
                                    $self->TRAININGFLAGS." ".
                                    $self->decrypted_steps, dodie=>1);
    }

    method reduce_oov() {
        if ($self->NBESTOOV ne "") {
            return $self->safeSystem($self->playground."/tools/reduce-oov.pl ".
                                    "--extract-outdir ".$self->step_tempdir."/model ".
                                    "--scripts-rootdir ".$self->moses_scripts_dir." ".
                                    "--output-alignments ".
                                    "--nbest ".$self->NBESTOOV." ".
                                    "--output-dir ".$self->step_tempdir."/reduce-oov ".
                                    "--temp-dir ".$self->get_temp, dodie=>0)
                   and
                   $self->safeSystem("mv ".$self->step_tempdir."/reduce-oov/* ".$self->step_tempdir."/model", dodie=>0);
        } else {
            return 1;
        }
    }

    method filter_tm() {
        return $self->safeSystem($self->playground."/tools/filter-several-phrasetables.pl ".
                            "--srccorp=".$self->SRCCORP." --srcaug=".$self->SRCAUG." ".
                            "--tgtcorp=".$self->TGTCORP." --tgtaug=".$self->TGTAUG." ".
                            "--cutoff=".$self->CUTOFF." --threshold=".$self->THRESHOLD." ".
                            "--workspace=".$self->binaries_dir." ".
                            $self->step_tempdir."/model/phrase-table.*", dodie=>0);

    }


    method really_make_tm() {
        if ($self->train_model(4,6)
            and
            $self->reduce_oov()
            and
            $self->filter_tm()
            and
            $self->train_model(8,8)
            ) {
            
            for ("model/extract*", "alignment.*.src", "alignment.*.tgt", "alignment.*.custom") {
                $self->safeSystem("rm -r ".$self->step_tempdir."/".$_, dodie=>0);
            }
            $self->safeSystem("rsync -uavz ".$self->step_tempdir."/* ./", e=> "Assumed success but rsync back failed");
            $self->safeSystem("rm -rf ".$self->step_tempdir, dodie=>0);
            
        } else {
           $self->safeSystem("rsync -uavz ".$self->step_tempdir."/log* ./", e=> "Failure, and rsync back failed");
           print "ONLY log copied back. Majority of files left here: ".$self->step_tempdir."\n";
           $self->myDie("THERE WERE ERRORS!! See above.");  
        }
    }

    method check_phrase_count() {
         print "Getting phrase counts...\n";
         $self->safeSystem($self->playground."/tools/zwc -l model/*.gz | tee phrase-counts", e=> "Failed to count phrases");
         if ($self->safeBacktick("cut -f1 phrase-counts")==0) {
             $self->myDie("Empty ttable, perhaps full temp disk above?");
         }
    }



}

1;
