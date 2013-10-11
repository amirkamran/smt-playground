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
    method myDie(Str $what) {
        if ($self->__is_preparing) {
            die $what;
        } else {
            $self->emanFail($what);
        }
    }

    #superhackery
    #gets a bash command, returns a sh command that can be run
    #using backticks/system with the same results
    #because those use sh, not bash
    method to_bash(Str $what) {
        $what =~ s/'/'"'"'/g;
        $what = "/usr/bin/env bash -c '$what\n\nexit \$?'";
        return $what;
    }

    method default_bash_context() {
        my $bc = new BashContext(prefixes=>[$self->localenfo, "set -o pipefail", 'renice 10 $$ 2>/dev/null >/dev/null', 'ulimit -c 1']);
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
    
    
    method safeSystem(Str $what, Str :e($errorForDying)="", Bool :$mute=0, Bool :$dodie=1, Maybe[BashContext] :bc($bashContext)=$undef) {
        return $self->safeSystemBacktick($what, $errorForDying, $mute, $dodie, $bashContext, 0);
    }

    method safeSystemBacktick(Str $what, Str $errorForDying, Bool $mute, Bool $dodie, Maybe[BashContext] $bashContext, Bool $isBacktick) {
        my $popis = $isBacktick ? "backtick":"system";
        if (!defined $bashContext) {
             $bashContext = ($self->default_bash_context)       
        }
        if (!$mute) {
            print "\n---safe$popis---\n";
            print $what;
            print "\n---\n";
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


    method emanAddDeps(ArrayRef[Str] $deps) {
        $self->safeSystem("eman add-deps . ".join(" ", @$deps));
    }

    method emanSaveDefvar(Str $var) {
        my $what = $self->meta->get_attribute($var)->get_value($self);
        $what =~ s/'/'"'"'/g;
        $self->safeSystem("export $var='".$what."'\n\neman defvar $var");
    }

    #this returns "eman defvar", which defines the eman command
    #that tries to load the vars and, maybe, redefine it and 
    #finally save it to eman.vars file
    method emanDefvarsCommand(ArrayRef[Str] $vars) {
        my $res="eman ";
        my $meta = $self->meta;
        for my $var (@$vars) {
            $res .= "defvar ";
            $res .= $var;
            my $help = $meta->get_attribute($var)->help;
            $help =~ s/'/'"'"'/g;
            $res .= " help='$help' ";
            $res .= $meta->get_attribute($var)->attrs;
            $res .= " ";
        }

        $res =~ s/\n/ /;
        return $res;
        
    }


    #superhackery
    #the only way I can think of for reading bash code from a file (eman.vars)
    #and finding out which variables were changed
    method superhack__findChangedDefvars() {
        if (!-e "eman.vars") {
            $self->myDie ("eman.vars not existent");
        }
        my $vars_string = `cat eman.vars`;
        my $to_run=$self->to_bash(q/

        RES=` perl -e 'use YAML::XS; print Dump \%ENV' `

        set -a

        /.
        $vars_string.
        '

        set +a

        echo "$RES" | perl -e \'$str = do { local $/; <STDIN> }; 
                                use YAML::XS; 
                                $oldenv=Load $str; 
                                %ch=();
                                for $k (keys %ENV) {if ($oldenv->{$k} ne $ENV{$k}){$ch{$k}=$ENV{$k}}}
                                print Dump \%ch
                                \'');
        my $res = `$to_run`;
        return Load $res;
        
    }
    
    #this does the whole "deal with defvars"
    #meaning - takes defined defvars, save them with eman and
    #resets the changed one.
    #It should not be overloaded by the child classes, nor directly called from them,
    #but it could be if really needed for some reason.
    method reloadAndSaveVars() {
        my $vars = $self->emanDefvarList;

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
            
            $attr->set_value($self, $changed_vars->$var);
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
        $self->__is_preparing(1);
        $self->reloadAndSaveVars;
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
        my $class = shift;
        my $that = $class->loadFromYaml;
        $that->__is_preparing(0);
        $that->print_start;
        $that->run;
        $that->do_end;
    }


}


1;


