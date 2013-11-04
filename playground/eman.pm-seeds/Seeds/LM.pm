use warnings;
use strict;
use MooseX::Declare;

class Seeds::LM with (Roles::KnowsMkcorpus, Roles::AccessesSrilm, Roles::KnowsCorpman) {
    use HasDefvar;
    
    has_defvar 'CORP'=> (help=>'the shortname of corpus');
    has_defvar 'CORPAUG'=> (help=>'the language+factors for the lm');
    has_defvar 'ORDER'=> (help=>'the lm order');
    has_defvar 'PARTS'=> (default=>1, help=>'build a huge lm in N parts');
    has_defvar 'LMFLAGS'=>(default=>'', help=>'flags for ngram-count like -unk');

    
    method help() {
        " Eman seed for constructing an n-gram language model. Binarization now excluded, because there are different (KenLM/IrstLM) binarization options."
    }
    
    method init(){
        if ($self->PARTS != 1 ) {
            print "!!!!!!!!\n\nLM with PARTS>1 is currently not working\n\n!!!!!!\n";
        }

        my $corpstep=$self->read_corp_info(
                               corpname=>$self->CORP ,
                               aug=>$self->CORPAUG,
                               var=>"stepname"
                            );
        
        $self->emanAddDeps([$corpstep]);
    
    }


    method prepare() {
    }

    method run() {
       
        $self->mkcorpus_do($self->CORP, $self->CORPAUG, "text");
        $self->generate_model();
        if (!-e "corpus.lm") {
            $self->myDie("No resulting corpus.lm");
        }
        $self->safeSystem("gzip corpus.lm"); 

    }



    method kndiscounts() {
        return join ("", map {" -kndiscount$_ "} (3..$self->ORDER) );
    }

    method simple_count_first_attempt() {
        return ($self->safeSystem("zcat corpus.text.gz | ngram-count -order ".$self->ORDER.
                    " -text - ".
                    " -lm corpus.lm ".
                    $self->LMFLAGS.
                    " -interpolate -kndiscount", dodie=>0))
    }

    method simple_count_second_attempt(){
                print "Second attempt, skip bigrams in knsmoothing\n";
                $self->safeSystem("zcat corpus.text.gz | ngram-count -order ".$self->ORDER .
                    " -text - ".
                    $self->LMFLAGS.
                    " -lm corpus.lm ".
                    " -interpolate ".
                    $self->kndiscounts, e=> "ngram-count FAILED even with bigrams not knsmoothed");
    }

    method simple_count() {
           print "Simple counting\n";
           if (! $self->simple_count_first_attempt()) {
                $self->simple_count_second_attempt();
           }
    }

    #note: this part is not working at all anyway
    method batch_count_preparation() {
           my $partstempdir=$self->safeBacktick("mktemp -d ".$self->tempdir."/exp.lm.XXXXXX");
            print "Counting in ".$self->PARTS." parts, tempdir=$partstempdir\n";
            $self->safeSystem("zcat corpus.text.gz | split_even ".$self->PARTS." $partstempdir/part --gzip",
                            e=>"Splitting FAILED");
            
            $self->safeSystem("ls $partstempdir/part*.gz > $partstempdir/filelist");
            return $partstempdir;
    }

    method batch_count_make(Str $partstempdir) {
            print "Making batch counts\n";
            $self->safeSystem("make-batch-counts $partstempdir/filelist 1 zcat $partstempdir ".
                                 " -order ".$self->ORDER.
                                 " ".$self->LMFLAGS.
                                 " -interpolate -kndiscount ", e=>"make-batch-counts FAILED");
    }

    method batch_count_merge(Str $partstempdir) {
            print "Merging batch counts\n";
            
            $self->safeSystem("merge-batch-counts $partstempdir", e=>"merge-batch-counts FAILED");

            $self->safeSystem("make-big-lm -read $partstempdir/*.ngrams.gz ".
                                " -name $partstempdir/biglm ".
                                " -order ".$self->ORDER ." ".
                                $self->LMFLAGS.
                                " -interpolate -kndiscount ".
                                ' -lm `pwd`/corpus.lm ', e=>"make-big-lm FAILED");
    }

    method batch_count_cleanup(Str $partstempdir){
            print "Removing $partstempdir\n";
            $self->safeSystem("rm -rf $partstempdir");
   }

    method batch_count() {
            my $partstempdir = $self->batch_count_preparation(); 
            $self->batch_count_make($partstempdir);
            $self->batch_count_merge($partstempdir);
            $self->batch_count_cleanup($partstempdir);
    }

    method generate_model() {

         if ($self->PARTS == 1) {
   
            $self->simple_count();

         } else {
            $self->batch_count();     
         }

    }


}

1;
