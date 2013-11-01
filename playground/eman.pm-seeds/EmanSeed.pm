use warnings;
use strict;

use MooseX::Declare;

class BashContext {
    has 'prefixes' => (isa=>'ArrayRef[Str]', is=>'rw', default=>sub{[]});
    method add_prefix(Str $what) {
        push @{$self->prefixes}, $what
    }

    method joined_prefixes() {
        return join ("", map {
            my $r = $_;
            my $f = $r;
            $f =~s/'/'"'"'/g;
            $f =~s/\n/ /g;
            $r.=" || ( echo 'problem with $f'; exit -1 )\n\n" if $r !~ /\n$/;
            $r;
        } @{$self->prefixes});
    }

    method copy() {
        my @copy = @{$self->prefixes};
        return new BashContext(prefixes=>\@copy);
    }
}

role EmanSeed {

    

    use MooseX::Storage;

    use YAML::XS;
    with Storage('format' => 'YAML', 'io' => 'File');
     
    has '__is_preparing' => (isa=>'Bool', is=>'rw');

    #0 => it is still loading
    #1 => not loading, but still init/prepare, so changing vars is possible
    #2 => changing vars is not possible
    has '__has_fully_loaded_defvars' => (isa=>'Int', is=>'rw');
    method myDie(Str $what) {
        if ($self->__is_preparing) {
            die $what;
        } else {
            $self->emanFail($what);
        }
    }

    method is_on_cluster() {

        my $r = $self->safeBacktick('which qsub', dodie=>0, mute=>1);
        if (length $r > 1) {
            return 1;
        }
        return 0;
    }

    #superhackery
    #gets a bash command, returns a sh command that can be run
    #using backticks/system with the same results
    #because perl by default uses sh, not bash
    #and on debian and ubuntu,
    #sh is some weird shell interpreter that sometimes behaves strange
    method to_bash(Str $what) {
        $what =~ s/'/'"'"'/g;
        $what = "/usr/bin/env bash -c '$what\n\nexit \$?'";
        return $what;
    }

    method default_bash_context() {
#        my $bc = new BashContext(prefixes=>[]);
         my $bc = new BashContext(prefixes=>[$self->localenfo, "set -o pipefail", 'renice 10 $$ 2>/dev/null >/dev/null', 'ulimit -c 1']);
        if ($self->__is_preparing == 0) {
            $bc->add_prefix(". /net/projects/SGE/user/sge_profile 2>/dev/null");
        }
        return $bc;
    }

    method bash_preparing(Str $what, BashContext $bc) {
        return $self->to_bash($bc->joined_prefixes."$what");
    }

   
    #hack for MooseX::Declare
    my $undef = undef;
    method safeBacktick(Str $what, Str :e($errorForDying)="", Bool :$mute=0, Bool :$dodie=1, Maybe[BashContext] :bc($bashContext)=$undef) {
        return $self->safeSystemBacktick($what, $errorForDying, $mute, $dodie, $bashContext, 1);
    }
    
    method get_temp() {
        my $tempdir=$ENV{TMPDIR};
       
        if ((!defined $tempdir) or $tempdir eq "" or (!-w $tempdir) or (!-d $tempdir)) {
            $tempdir="/mnt/h/tmp";
        }
        if (!(-d $tempdir) or (!-w $tempdir)) {
            $tempdir = "/tmp";
       
        }
        #absolute failsafe
        if (!(-d $tempdir) or (!-w $tempdir)) {
            $tempdir = `pwd`;
            chomp $tempdir;
            $tempdir.="/tmp";
            system("mkdir $tempdir");
        }
        return $tempdir;

    }

    method safeSystem(Str $what, Str :e($errorForDying)="", Bool :$mute=0, Bool :$dodie=1, Maybe[BashContext] :bc($bashContext)=$undef) {
        return $self->safeSystemBacktick($what, $errorForDying, $mute, $dodie, $bashContext, 0);
    
    }

    #(you might think I am crazy, but this seems to work)
    #I run every command as sh command,
    #that runs bash,
    #that FIRST does things in $bashContext, like setting up all the env variables
    #and only after that, I run the command itself
    #and test it on true/false exit value, and die if it's wrong
    #I also print the command itself out - it can seem silly but it's really useful for debugging
    method safeSystemBacktick(Str $what, Str $errorForDying, Bool $mute, Bool $dodie, Maybe[BashContext] $bashContext, Bool $isBacktick) {
        my $popis = $isBacktick ? "backtick":"system";
        if (!defined $bashContext) {
             $bashContext = ($self->default_bash_context)       
        }
        if (!$mute) {
            print "--- safe$popis [[[ ";
            print $what;
            print " ]]] \n";
        }

        my $torun = $self->bash_preparing($what, $bashContext);
        if ($errorForDying eq "") {
            $errorForDying = "Cannot run $what!";
        }
        my $res = $isBacktick? `$torun`:!(system($torun));
        chomp $res if $isBacktick;
        my $shoulddie = $isBacktick ? ($? != 0) : (!$res);
        if ($dodie and $shoulddie) {
                $self->myDie($errorForDying);
        }
        return $res;
    }


    has 'mydir'=> (isa=>'Str', is=>'ro', default=>sub{my $r= `pwd`;chomp($r);return $r});
    has 'playground'=> (isa=>'Str', is=>'ro', default=>sub{my $r= `eman path`;chomp($r);return $r});
    has 'localenfo'=> (isa=>'Str', is=>'ro', default=>sub{return `locale | sed 's/^/export /'`});

    method corpmanCommand(ArrayRef[Str] $what) {
        return $self->playground."/corpman ".join(" ", @$what);
    }

    method emanPath(Str $what) {
        my $path= $self->safeBacktick('eman path '.$what, mute=>1) ;
        if (!defined $path or $path eq "") {
            $self->myDie("Not existent path for step $what");
        }
        if (!-d $path) {
            $self->myDie($what." - path for $what - is not a directory");
        }
        return $path
    }

    #not using safeSystem dodie because myDie uses emanFail
    method emanFail(Str $why) {
        $self->safeSystem("eman fail ".$self->mydir, dodie=>0, mute=>1) or die "Failing to do 'eman fail' :(";
        die $why;
    }

    #list of all defvars, from the class definition in source code
    method emanDefvarList() {
        my @list;
        my $meta = $self->meta;
        for my $attribute ( map { $meta->get_attribute($_) }
                   sort $meta->get_attribute_list ) {
                if ($attribute->does('Defvar')) {
                    push(@list, $attribute->name);
                }
        }
        return \@list;        
    }


    method emanSaveTag(Str $tag) {
        open my $f, ">", "eman.tag" or $self->myDie("could not open eman.tag");
        print $f $tag;
        close $f;
        
    }


    method emanGetTag(Str $step) {
        return $self->safeBacktick("eman tag $step", mute=>1);
    }

    method emanGetVar(Str $step, Str $var) {
        return $self->safeBacktick("eman getvar $step $var", mute=>1);
    }

    method emanAddDeps(ArrayRef[Str] $deps) {
        $self->safeSystem("eman add-deps . ".join(" ", @$deps));
    }

    #this should be run only by triggering changes in defvars
    #see HasDefvar
    #not from modules themselves
    method _emanSaveDefvar(Str $var) {
        my $what = $self->meta->get_attribute($var)->get_value($self);
        $what =~ s/'/'"'"'/g;
        $self->safeSystem("export $var='".$what."'\n\neman defvar $var", mute=>1);
    }

    method scriptsDir() {
        return $self->playground."/../scripts/";
    }

    method wiseLn(Str $from, Str $to, Bool :$justCommand=0) {
        my $comm = $self->scriptsDir."/wiseln $from $to";
        if ($justCommand) { 
            return $comm;
        }
        $self->safeSystem($comm);        
    }

    #this returns "eman defvar", which defines the eman command
    #that tries to load the vars and, maybe, redefine it and 
    #finally save it to eman.vars file
    method emanDefvarsCommand(ArrayRef[Str] $vars) {
        my $res="eman ";
        my $meta = $self->meta;
        my @allvars = @$vars;
        #primitive sorting: first those without inheritance
        #so the "inherited" can depend on them
        #TODO: something smarter?
        my @not_inherited = grep {!$meta->get_attribute($_)->is_inherited} @allvars;
        my @inherited = grep {$meta->get_attribute($_)->is_inherited} @allvars;
        
        for my $var (@not_inherited, @inherited) {

            $res .= "defvar ";
            $res .= $var;
            my $attribute = $meta->get_attribute($var);
            #TODO: nicer :-(
            my $help = $attribute->help;
            $help =~ s/'/'"'"'/g;
            $res .= " help='$help' ";


            if ($attribute->has_inherit) {
                my $inherit = $attribute->inherit;
                $inherit =~ s/'/'"'"'/g;
                $res .= " inherit='$inherit' ";
            }
            if ($attribute->has_firstinherit) {
                my $firstinherit = $attribute->firstinherit;
                $firstinherit =~ s/'/'"'"'/g;
                $res .= " firstinherit='$firstinherit' ";
            }
            if ($attribute->has_same_as) {
                my $same_as = $attribute->same_as;
                $same_as =~ s/'/'"'"'/g;
                $res .= " same_as='$same_as' ";
            }
            if ($attribute->has_type) {
                my $t = $attribute->type;
                $t =~ s/'/'"'"'/g;
                $res .= " type='$t' ";
            }
            if ($attribute->has_eman_default) {
                my $default = $attribute->eman_default;
                $default =~ s/'/'"'"'/g;
                $res .= " default='$default' ";
            }
            #$res .= $meta->get_attribute($var)->attrs;
            #$res .= " ";
        }

        #print "[[[[ $res ]]]]\n";
        $res =~ s/\n/ /;
        
        return $res;
        
    }


    #(superhackery I am not very proud of... but it works)
    #the only way I can think of for reading bash code from a file (eman.vars)
    #and finding out which variables were changed
    method superhack__findChangedDefvars() {
        if (!-e "eman.vars") {
            $self->myDie ("eman.vars not existent");
        }
        my $vars_string = `cat eman.vars`;
        my $to_run=$self->to_bash(q/

        #first, save all env to variable
        RES=` perl -e 'use YAML::XS; print Dump \%ENV' `

        set -a

        #then print all variables, set is -a for remembering all of them in env
        /.
        $vars_string.
        '

        set +a

        #then read the former env to perl script
        #which compares it to the new one
        echo "$RES" | perl -e \'$str = do { local $/; <STDIN> }; 
                                use YAML::XS; 
                                $oldenv=Load $str; 
                                %ch=();
                                for $k (keys %ENV) {if ($oldenv->{$k} ne $ENV{$k}){$ch{$k}=$ENV{$k}}}
                                
                                #then we print all the differences out YAMLed
                                print Dump \%ch
                                \'');

        #which is then captured to a variable
        my $res = `$to_run`;

        #that's again YAML-loaded and returned
        return Load $res;
       
        #it's superugly and it probably forks like crazy
        #(remember, that I also run the whole thing in sh, that forks its own bash)
    }
    
    #this does the whole "deal with defvars"
    #meaning - takes defined defvars, save them with eman and
    #resets the changed one.
    #It should not be overloaded by the child classes, nor directly called from them,
    #but it could be if really needed for some reason.
    method reloadAndSaveVars() {
        my $vars = $self->emanDefvarList;

        if (scalar @$vars==0) {
            print "No vars!\n";
            $self->safeSystem("touch eman.vars");
            return;
        }
        #$self->loadFromEnv($vars);

        my $meta = $self->meta;

        $self->safeSystem($self->emanDefvarsCommand($vars), e=>"Couldn't register vars", mute=>1);

        my $changed_vars = $self->superhack__findChangedDefvars;
        
        for my $var (keys %$changed_vars) {
            my $attr = $meta->get_attribute($var);
            if (!defined $attr) {
                $self->myDie ("not a valid attribute $attr");
            }
            if (!$attr->does('Defvar')) {
                $self->myDie( "Cannot change attribute $attr - not a defvar");
            }
            print "eman defvar changed ".$var." to ".($changed_vars->{$var})."\n";
            
            $attr->set_value($self, $changed_vars->{$var});
        }
        $self->ensureDefined($vars);

    }
    
    #method loadFromEnv(ArrayRef[Str] $vars) {
    #    for my $var (@$vars) {
    #        $self->meta->get_attribute($var)->set_value($self, $ENV{$var});
    #    }
    #}

    method ensureDefined(ArrayRef[Str] $vars) {
        for my $var (@$vars) {
            my $res = $self->meta->get_attribute($var)->get_value($self);
            if (!defined $res) {
                $self->myDie( "Undefined var $var");
            }
        }
    }
    
    method saveToYaml() {
        $self->store('eman.module-vars.yaml');
    }
    
    sub loadFromYaml {
        return $_[0]->load('eman.module-vars.yaml');
    }

    method print_stat(Str $text) {
        print "==============================\n";
        print "== ".$text.":   ";
        print $self->safeBacktick(q(date '+%Y%m%d-%H%M'), mute=>1);
        print "\n";
        print "== Hostname:  ";
        print $self->safeBacktick('hostname', mute=>1);
        print "\n";
        print "== Directory: ";
        print $self->safeBacktick('pwd', mute=>1);
        print "\n==============================\n";
    }

    method print_start() {
        $self->print_stat("Started");
    }


    method do_end() {
        $self->safeSystem("eman succeed ".$self->mydir, e=>"Cannot eman succeed");
        $self->print_end; 
    }
    method print_end() {
        print "Done\n";
        $self->print_stat("Ended");
    }




    requires 'init';
    requires 'prepare';
    requires 'run';
    requires 'help';
   
    method _do_init() {
        $|=1;
        $self->__is_preparing(1);
        $self->__has_fully_loaded_defvars(0);
        $self->reloadAndSaveVars;
        $self->__has_fully_loaded_defvars(1);
        $self->init;
    }

    method _do_prepare() {
        $self->__is_preparing(1);
        $self->_do_init;
            #I have to do it again to load all the vars
        $self->prepare;
        $self->saveToYaml;
    }

    sub _do_run {
        $|=1;
        my $class = shift;
        my $that = $class->loadFromYaml;
        $that->__is_preparing(0);
        $that->__has_fully_loaded_defvars(2);
        $that->print_start;
        $that->run;
        $that->do_end;
    }

    use HasDefvar;
    has_defvar 'EMAN_MEM'=>(default=>'6g', help=>'memory limit for the job itself');
    has_defvar 'EMAN_DISK'=>(default=>'6g', help=>'free space on the temp disk');
    has_defvar 'EMAN_CORES'=>(default=>'1', help=>'number of CPUs to use in Moses');
    
    use Moose::Exporter;
    Moose::Exporter->setup_import_methods(
      with_meta => [ 'has_defvar'],
      also=>'MooseX::Declare');

   
    method write_help {
        print ref $self;
        print "\n";
        print $self->help();
        print "\n-------------------\n";
        my $list = $self->emanDefvarList;
        for my $defvar (sort {$a cmp $b} @$list) {
            my $attribute = $self->meta->get_attribute($defvar);
            print "$defvar";
            
            if ($attribute->has_eman_default) {
                my $default = $attribute->eman_default;
                print " [$default] ";
            }
            
            print " --  ";
            print $attribute->help."\n";
            if ($attribute->has_inherit) {
                my $inherit = $attribute->inherit;
                print "  inherited from: $inherit \n";
            }
            if ($attribute->has_firstinherit) {
                my $firstinherit = $attribute->firstinherit;
                print "  inherited from first: $firstinherit \n";
            }
            if ($attribute->has_same_as) {
                my $same_as = $attribute->same_as;
                print "  same as: $same_as \n";
            }
            if ($attribute->has_type) {
                my $t = $attribute->type;
                print "  type: $t\n";
            }
        }
    }

}


1;


