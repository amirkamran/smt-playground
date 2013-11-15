use warnings;
use strict;
use MooseX::Declare;

class Seeds::Model with (Roles::KnowsMkcorpus, Roles::AccessesMosesBinaries, Roles::HasDecodingSteps) {
    use HasDefvar;
    
    has_defvar 'TMS'=>(help=>'extracted phrases, a colon-separated lists of s.tm', type=>"steplist");
    has_defvar 'LMS'=>(help=>'tgtfactoridx:lmstep:::tgtfactoridx:lmstep:::tgtfactoridx:lmstep');
    has_defvar 'GLM'=>(help=>'optional glm step, format: factors:glmstep, e.g. 0-0:s.glm.xyz', default=>'');
    has_defvar 'CONFIGARGS'=>(default=>'', help=>'additional arguments passed to train-model.perl');
    has_defvar 'RMSTEP'=>(default=>'', type=>'optstep', help=>'lexicalized reordering model');
    
    #overloading the one in AccessesMosesBinaries
    has_defvar 'MOSESSTEP' => (help=>'moses scripts and binaries (default to inherit from the first TM)', type=>'reqstep', firstinherit=>'TMS' );

    has_defvar 'TGTAUG'=> (firstinherit=>'TMS', help=>"the string describing lang+factors of tgt corpus");
    has_defvar 'SRCAUG'=> (firstinherit=>'TMS', help=>"the string describing lang+factors of src corpus");
  
    #overloads defvar in HasDecodingSteps because of inheritance
    has_defvar 'DECODINGSTEPS'=> (firstinherit=>'TMS',
            help=>"specification of decoding steps, e.g. t0a1-0+t1-1");

    has_defvar 'THRESHOLD'=> (firstinherit=>'TMS',
            help=>"a+e, a-e of a number (see moses/sigtest-filter)" );
    has_defvar 'CUTOFF'=> (firstinherit=>'TMS',
            help=>"phrase-table cutoff" );

    has_defvar 'LM_BACKOFF'=> (default=>'no',
            help=>"if set as 'yes', other than the first LM is set as backoff model" );

    method help() {
        "eman seed for the preparation of moses.ini file by combining:"
        ."\ntranslation model(s)"
        ."\n(optional reordering model)"
        ."\nlanguage models"
        ."\n(optional global lexicon model)"
    }


    method init() {
        for my $lm (split (/:::/, $self->LMS)) {
            my (undef, $step, undef) = split (/:/, $lm);
            $self->emanAddDeps([$step]);
        }
        if ($self->GLM) {
            print "WARNING\n\nGLM not tested at all in Model.pm, might not work";
        }
        if ($self->RMSTEP) {
            print "WARNING\n\nRMSTEP not tested at all in Model.pm, might not work";
        }
    }
    method prepare() {
        $self->load_glm();
        $self->load_reordering();
    }

    method run(){
        my @tms= $self->clone_tm();
        $self->clone_rm();
        my ($lmopts, $lmsize) = $self->clone_lm();
        $self->make_inis($lmopts, \@tms);
        $self->add_backoff($lmsize);
        $self->add_glm();
    }

    method clone_tm() {
        $self->safeSystem("rm -rf tm*");
        my $i=0;
#        if ($self->RMSTEP) {
        my @paths;
        my @tms = split(/:/, $self->TMS);
        for my $tm_step (@tms) {
            $i++;
            my $tm = $self->emanPath($tm_step);
            push @paths, $tm;
            for my $f  (<$tm/model/*gz>) {
                my $basename = $self->safeBacktick("basename $f");
                $self->safeSystem("mkdir -p tm.$i/model");
                $self->wiseLn($f , "./tm.$i/model/$basename");
            }
        }
        return @paths;

    }

    method clone_rm() {
        
        if ($self->RMSTEP) {
            $self->safeSystem("cd tm.1/model", e=> "Failed to implant reordmodel to tm.1");
            my $p = $self->emanPath($self->RMSTEP);
            for my $f  (<$p/model/reordering-table*gz>) {
                my $basename = $self->safeBacktick("basename $f");
                $self->wiseLn($f, "tm.1/model/$basename");
            }
        }
    }

    method clone_lm() {
        my $lmopts="";
        my $i = 0;
        for my $lm  (split (/:::/, $self->LMS)) {
            $i++;
            my ($factor, $lmstep, $lmtype) = split (/:/, $lm);
            use 5.010;
            $lmtype = $lmtype//"";
            my $lmstepdir=$self->emanPath($lmstep);
            print "Cloning lm from $lmstep ($lmstepdir), using lmtype ".$lmtype;
            my $num_type;my $suffix;
            if ($lmtype eq "blm"){
                $num_type=1;
                $suffix=$lmtype;
            } elsif ($lmtype eq "flm"){
                $num_type=7;
                $suffix=$lmtype;
            } else {
                $num_type=8;
                $suffix="lm";
            }

            my $this_filename;
            if ($suffix eq "flm") {
                $self->wiseLn("$lmstepdir/config.prepared.flm", "./lm.$i.$suffix");
                $this_filename = "lm.$i.$suffix";
            } else {
                if (-e "$lmstepdir/binarized") {
                    $self->wiseLn("$lmstepdir/binarized", "./lm.$i");
                    $this_filename = "lm.$i";
                } else {
                    if ( -e "$lmstepdir/corpus.$suffix.gz") {
                        # prefer gzipped, kenlm (8) supports this
                        $suffix.=".gz";
                    }
                    $self->wiseLn("$lmstepdir/corpus.$suffix", "./lm.$i.$suffix");
                    $this_filename = "lm.$i.$suffix";
                }
            }
            my $order = $self->emanGetVar($lmstep, "ORDER");
            $lmopts .= "  --lm $factor:$order:".$self->mydir."/$this_filename:$num_type "
        }

        return ($lmopts, $i);
    }


    method make_inis(Str $lmopts, ArrayRef[Str] $tm_paths) {
        my $i=0;
        for my $tm_path (@$tm_paths) {
            my $loc_bc = $self->default_bash_context;
            $i++;
            $loc_bc->add_prefix("cd tm.$i");
            $self->safeSystem(join (" ",
                    $self->moses_scripts_dir."/training/train-model.perl",
                    "--force-factored-filenames",
                    "--first-step 9 --last-step 9",
                    "--root-dir .",
                    "--alignment-file=alignment ",
                    "--alignment=custom",
                    "--corpus=corpus/corpus",
                    "--f src --e tgt",
                    "--reordering", $self->reordering, 
                    "--reordering-factors", $self->reordfactors,
                    $self->CONFIGARGS,
                    $lmopts,
                    $self->decrypted_steps), e=>"Failed to create moses.ini", bc=>$loc_bc);
             if (-e "$tm_paths/var-SCRADDED") {
                  $loc_bc->add_prefix("cd model");
	              my $adder = $self->playground."/tools/alter-moses-ini-ttable-weights.pl";
                  if (!-x $adder) {$self->myDie("Missing or not executable $adder")}
                  $self->safeSystem("cp ./moses.ini ./moses.ini.copy", bc=>$loc_bc);
                  $self->safeSystem("cat ./moses.ini.copy | $adder `cat $tm_path/var-SCRADDED`", bc=>$loc_bc);
                  $self->safeSystem("rm ./moses.ini.copy", bc=>$loc_bc);
            }
        }
        $self->safeSystem("mkdir model");
        $self->safeSystem($self->scriptsDir."/merge_moses_models.pl --append-unknown --no-concat-lms tm.*/model/moses.ini > ./model/moses.ini", e=> "Merge moses.ini failed");
    
    }


    method add_backoff(Int $lm_size) {
        if ($self->LM_BACKOFF eq "yes") {
            #\n is really \n, not a newline, it's for sed
            my $backofftag='[decoding-graph-backoff]\n';
            $backofftag.='0\n';
            for (2..$lm_size) {
                $backofftag.='20\n';
            }
            $self->safeSystem('sed -i \'s/\[feature\]/'.$backofftag.'\n[feature]/\' ./model/moses.ini');
        }
    }

    method add_glm() {
        if ($self->glmdir){
            $self->safeSystem("mkdir glm");
            $self->wiseLn($self->glmdir."/model/glm" ,"glm/glm", e=> "Failed to clone glm");
            $self->safeSystem("echo -e \"\n".
                                "[global-lexical-file]\n".
                                $self->GLMFACTORS." ".$self->mydir."/glm/glm\n\n".
                                "[weight-lex]\n".
                                "1.0\n\"".
                                " | tee glm/moses.ini >> ".$self->mydir."/model/moses.ini",
                          e=> "Failed to add glm to moses.ini");
            }
 
    }
 
    

    has 'glmfactors'=>(isa=>'Str', is=>'rw');
    has 'glmdir'=>(isa=>'Str', is=>'rw');
    method load_glm() {
        if ($self->GLM) {
            my ($factors, $step) = split (/:/, $self->GLM);
            $self->glmfactors($factors);
            $self->glmdir($self->emanPath($step));
            $self->emanAddDeps([$step]);
        }
    }

    has 'reordering'=>(isa=>'Str', is=>'rw');
    has 'reordfactors'=>(isa=>'Str', is=>'rw');

    method load_reordering() {
        if (!$self->RMSTEP) {
            $self->reordering("distance");
            $self->reordfactors("0-0");
            #$self->dotreordtag("");
        } else {
            if ($self->PROMISEAUGMATCH eq "yes"
                and $self->TGTAUG ne $self->emanGetVar($self->RMSTEP, "TGTAUG")) {
                $self->myDie("Incompatible TGTAUGs");
            }
            if ($self->PROMISEAUGMATCH eq "yes"
                and $self->SRCAUG ne $self->emanGetVar($self->RMSTEP, "SRCAUG")) {
                $self->myDie("Incompatible SRCAUGs");
            }
            $self->reordering($self->emanGetVar($self->RMSTEP, "REORDERING"));
            $self->reordfactors($self->emanGetVar($self->RMSTEP, "REORDFACTORS"));
            #$self->dotreordtag(".".$self->emanGetVar($self->RMSTEP, "REORDTAG"));
        }
           
    }
    
}

1;
