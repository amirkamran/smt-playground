use warnings;
use strict;
use MooseX::Declare;


#corpus has disadvantage that it is never run
#since corpman automatically uses the step "corpus" :)
class Seeds::Corpus with (Roles::HasJobsOnCluster) {
    use HasDefvar;
    
    has_defvar 'RUN_COMMAND'=>( help=>'apply the given pipe to the given input corpus. '.
                        'you *may* leave STEPNAME etc empty if the command produces '.
                        'everything <- this is not yet supported, because we '.
                        'wouldn\'t know the output line count'                               
                        , default=>'');
    has_defvar 'COMBINE_PARTS'=>( help=>'use factor_combinator.pl to combine multiple factors to a '.
                        'single corpus', default=>'');
    has_defvar 'TAKE_FROM_COMMAND'=>( help=>'run the command (no input) and collect its output', default=>'');
    has_defvar 'STEPNAME'=>( help=>'input step name', default=>'');
    has_defvar 'FILENAME' =>( help=>'input file name', default=>'');
    has_defvar 'COLUMN' =>( help=>'input column in the file, or -1', default=>-1);
    
    has_defvar 'FACTOR' =>( help=>'input factor in the column, or -1', default=>-1);
    has_defvar 'OUTCORP'=>( help=>'output corpus name');
    has_defvar 'OUTLANG'=>( help=>'output language name');
    has_defvar 'OUTFACTS'=>( help=>'output factors sequence');
    has_defvar 'OUTLINECOUNT' => ( help=>'forward check: expected number of lines');
    has_defvar 'DEPS' => ( help=>'steps we rely on', default=>'');
    has_defvar 'DERIVED' =>( help=>'is the corpus derived from an existing one', default=>0);
  
  
    method help() {
        return "Creates a corpus. It can work in exactly one of three modes:".
        "\n(1) Applying pipe to a given corpus - RUN_COMMAND and STEPNAME must be present.\n".
        "(2) Combine parts from more corpora - COMBINE_PARTS must be present\n".
        "(3) TAKE_FROM_COMMAND - just runs the command";
    }

    method init(){
        $self->register_corpman($self->OUTLINECOUNT);
    }

    method prepare() {
    }

    method run() {
        $self->run_cmd_and_gzip;
        $self->check_result_corpus;
        $self->force_reindexing;
    }



    #has 'split_to_size'=>(isa=>'Num', is=>'rw');
    method split_to_size(){50000}
    
    has 'cmd' => (isa=>'Str', is=>'rw', builder=>'get_cmd', lazy=>1);

    
   
    #jaký typ korpusu to je
    method type_of_corpus() {
        my $res=0;
        my $c=0;
        if ($self->RUN_COMMAND) {
            $c++;
            $res= 1; #z jineho stepu
        } 
        if ($self->COMBINE_PARTS){
            $c++;
            $res= 2; #faktor
        } 
        if ($self->TAKE_FROM_COMMAND)  {
            $c++; 
            $res = 3; #z take_from_command
        } 
        $c==1 or $self->myDie ("Bad usage: Needed exactly one of RUN_COMMAND, COMBINE_PARTS and TAKE_FROM_COMMAND, had $c");
        return $res;
    }

    method if_column() {
        if ($self->COLUMN!= -1) {
            return ("cut -f ".$self->COLUMN);
        }
        return ();
    }

    method if_factor() {
        if ($self->FACTOR!= -1) {
            return ($self->scriptsDir."/reduce_factors.pl  ".$self->FACTOR);
        }
        return ();
    }

    method get_qruncmd_command() {
       return $self->scriptsDir."/qruncmd --jobs=".$self->real_jobs." --attempts=5 --split-to-size=".$self->split_to_size." --join --jobname corpman.".$self->OUTCORP.".".$self->OUTLANG.' " ';
    }

    method get_cmd_run_command() {
        my $sn = $self->STEPNAME;
        $self->myDie ("Indicate where the source corpus is") if (!$sn);
        my $steppath = $self->emanPath($sn);
        chomp $steppath;
        if (!-e "$steppath/corpman.info") {
            $self->myDie ("$sn is not a corpus")
        }
        my $inf = $steppath."/".$self->FILENAME;
        if (! $self->real_jobs) {
           return join (" | ","zcat $inf", $self->if_column, $self->if_factor, $self->RUN_COMMAND);
        }

        my $res = $self->get_qruncmd_command;
        $res .= join (" | ", $self->if_column, $self->if_factor, $self->RUN_COMMAND.' " '.$inf);
       
        if ($self->OUTLINECOUNT != -1 ) {
            $res.=" --promise-linecount=".$self->OUTLINECOUNT;
        }
        return $res;
    }

    method get_cmd() {
        my $type = $self->type_of_corpus;
        if ($type==1) {
            return $self->get_cmd_run_command;
        }
        if ($type==2) {
            return "../factor_combinator.pl .".$self->COMBINE_PARTS;
        }
        return $self->TAKE_FROM_COMMAND;
    }

    method run_cmd_and_gzip() {
        $self->safeSystem($self->cmd." | gzip -c > corpus.txt.gz", e=>"Failed to prepare the corpus");    
    }
    
    method check_result_corpus() {
        my $nl = $self->safeBacktick("zcat corpus.txt.gz | wc -l", e=>"cannot count lines");
        if ($self->OUTLINECOUNT == -1) {
            print "Re-registering the corpus with $nl lines.\n";
            $self->register_corpman($nl, 0);            
        } else {
            if ($nl != $self->OUTLINECOUNT) {
                $self->myDie ("Mismatched number of lines, expected ".$self->OUTLINECOUNT.", got $nl");
            }
        }
    }

    method register_corpman(Int $linecount) {
        $self->safeSystem($self->corpmanCommand(["register",
                                                 "--", 
                                                 "corpus.txt.gz",
                                                 -1,
                                                 $self->OUTCORP, 
                                                 $self->OUTLANG, 
                                                 $self->OUTFACTS, 
                                                 $linecount, 
                                                 $self->DERIVED, 
                                                 $self->FACTOR]), e=>"Can't register corpus");
    }

    method force_reindexing() {
        $self->safeSystem("rm -f ".$self->mydir."/../corpman.index", e=>"Failed to force reindexing");
    }

}
1;
