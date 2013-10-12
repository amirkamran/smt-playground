use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

class Corpus with EmanSeed {
    use HasDefvar;
    
    has_defvar 'RUN_COMMAND'=>( help=>'apply the given pipe to the given input corpus. '.
                        'you *may* leave STEPNAME etc empty if the command produces '.
                        'everything <- this is not yet supported, because we '.
                        'wouldn\'t know the output line count'                               
                        , attrs=>q(default=''));
    has_defvar 'COMBINE_PARTS'=>( help=>'use factor_combinator.pl to combine multiple factors to a '.
                        'single corpus', attrs=>q(default=''));
    has_defvar 'TAKE_FROM_COMMAND'=>( help=>'run the command (no input) and collect its output', attrs=>q(default=''));
    has_defvar 'STEPNAME'=>( help=>'input step name', attrs=>q(default=''));
    has_defvar 'FILENAME' =>( help=>'input file name', attrs=>q(default=''));
    has_defvar 'COLUMN' =>( help=>'input column in the file, or -1', attrs=>q(default='-1'));
    
    has_defvar 'FACTOR' =>( help=>'input factor in the column, or -1', attrs=>q(default='-1'));
    has_defvar 'OUTCORP'=>( help=>'output corpus name');
    has_defvar 'OUTLANG'=>( help=>'output language name');
    has_defvar 'OUTFACTS'=>( help=>'output factors sequence');
    has_defvar 'OUTLINECOUNT' => ( help=>'forward check: expected number of lines');
    has_defvar 'DEPS' => ( help=>'steps we rely on', attrs=>q(default=''));
    has_defvar 'JOBS' =>( help=>'how many jobs to submit, 0 to disable SGE', attrs=>q(default='15'));
    has_defvar 'DERIVED' =>( help=>'is the corpus derived from an existing one', attrs=>q(default='0'));
   
    has 'split_to_size'=>(isa=>'Num', is=>'rw');
    has 'cmd' => (isa=>'Str', is=>'rw');

    method help() {
        return "Creates a corpus. It can work in exactly one of three modes:".
        "\n(1) Applying pipe to a given corpus - RUN_COMMAND and STEPNAME must be present.\n".
        "(2) Combine parts from more corpora - COMBINE_PARTS must be present\n".
        "(3) TAKE_FROM_COMMAND - just runs the command";
    }

   
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
            return (" ../../scripts/reduce_factors.pl  ".$self->FACTOR);
        }
        return ();
    }

    method get_qruncmd_command() {
       return "../../scripts/qruncmd --jobs=".$self->JOBS." --attempts=5 --split-to-size=".$self->split_to_size." --join --jobname corpman.".$self->OUTCORP.".".$self->OUTLANG.' " ';
    }

    method get_cmd_run_command() {
        my $sn = $self->STEPNAME;
        $self->myDie ("Indicate where the source corpus is") if (!$sn);
        my $steppath = $self->safeBacktick("eman path $sn", e=>"Cannot do eman path");
        chomp $steppath;
        if (!-e "$steppath/corpman.info") {
            $self->myDie ("$sn is not a corpus")
        }
        my $inf = $steppath."/".$self->FILENAME;
        if (! $self->JOBS) {
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
        $self->safeSystem($self->playground."/corpman register -- corpus.txt.gz -1 ".join(" ", ($self->OUTCORP, $self->OUTLANG, $self->OUTFACTS, $linecount, $self->DERIVED, $self->FACTOR)), e=>"Can't register corpus");
    }

    method force_reindexing() {
        $self->safeSystem("rm -f ".$self->mydir."/../corpman.index", e=>"Failed to force reindexing");
    }

    method init(){
        if (!$self->is_on_cluster) {
            $self->JOBS(0);
        }
        $self->split_to_size(50000);
        $self->register_corpman($self->OUTLINECOUNT);
        $self->cmd($self->get_cmd);
    }

    method prepare() {
    }

    method run() {
        $self->run_cmd_and_gzip;
        $self->check_result_corpus;
        $self->force_reindexing;
    }
}
1;
