use warnings;
use strict;
use MooseX::Declare;
use EmanSeed;

role Roles::KnowsCorpman with EmanSeed {


    method restart_corpman(){
        
        $self->safeSystem("rm ".$self->playground."/corpman.index");
    }

    method dump_corp(Str :$corpname,Str :$where, Str :$lang="", Str :$factors="", Str :$aug="" ) {
             if ($aug eq "") {
                if ($lang eq "" or $factors eq "") {
                    $self->myDie("either aug or both lang and factors has to be specified");
                }
                $aug = $lang."+".$factors; 
             }
            
            my $r = $self->_corpmanCommand(["--dump", "$corpname/$aug"])."> $where";
            $self->safeSystem($r);
            
    }

    method read_corp_info(Str :$corpname, Str :$lang="", Str :$factors="", Str :$var,Bool :$do_init=1, Str :$aug="") {
             if ($aug eq "") {
                if ($lang eq "" or $factors eq "") {
                    $self->myDie("either aug or both lang and factors has to be specified");
                }
                $aug = $lang."+".$factors; 
             } 
             
             my $initstr = $do_init?"--init":"";
             my $r = $self->_corpmanCommand([
                        "--factorindex", $initstr, 
                        $corpname."/".$aug,
                        " --bashvars=hack=".$var]);
             my $v = $self->safeBacktick($r);
             $v =~ /hack=(.*)/ or $self->myDie("Not defined $var in $v");
             my $s = $1;
             return $s;
            #die "VVVVV";
    }

    method aug_to_lang_and_factors(Str $aug) {
        my ($lang, $factors) = $aug =~ /^([^\+]*)\+(.*)$/ or $self->myDie( "wrong formatted aug $aug"); 
        return ($lang, $factors);
    }

    method promise_corp(Str :$filename, Int :$column, Str :$corpname, Str :$lang, Str :$factors, Int :$count, 
                        Str :$derived="", Str :$derived_facts="") {

#             my $initstr = $do_init?"--init":"";
             my $r = $self->_corpmanCommand([
                        "register",
                        #$initstr,
                        "--",
                        $filename,
                        $column,
                        $corpname,
                        $lang,
                        $factors,
                        $count,
                        $derived,
                        $derived_facts,
                        ]);

            $self->safeSystem($r);
    }

    method _corpmanCommand(ArrayRef[Str] $what) {
        return $self->playground."/corpman ".join(" ", @$what);
    }

}

1;
