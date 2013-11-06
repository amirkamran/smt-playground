use MooseX::Declare;

class Seeds::IdentAlign with (Roles::GeneralAlign){
    use HasDefvar;

    has_defvar 'CHECK_WORD_LENGTHS' => (help=>'yes if seed should also check word lengths', default=>'yes');

    #overloads defvar with non-defvar
    has 'ALISYMS'=>(is=>'ro', isa=>'Str', default=>'gdfa');

    method help() {
        "eman seed for identical word alignment without giza"
    }

  
    method actual_align() {
        $self->safeSystem("zcat < corpus.src.gz > corpus.src");
        $self->safeSystem("zcat < corpus.tgt.gz > corpus.tgt");

        open my $inf, "paste corpus.src corpus.tgt |"
            or $self->myDie("cannot paste corpus.src and corpus.tgt");

        binmode($inf, ":utf8");
        
        open my $outf, "| gzip -c > alignment.gz"
            or $self->myDie("cannot open output");
        binmode($outf, ":utf8");

        $self->ident_align($inf, $outf);
    }
           

    method ident_align(FileHandle $inf, FileHandle $outf) {
        use utf8; #for the lengths check
        while (my $line=<$inf>) {
            chomp $line;
            my ($s, $t) = split (/\t/, $line) or $self->myDie("wrong iput");
            my @s_words = split(/ /,$s);
            my @t_words = split(/ /,$t);
            my $wc = scalar(@s_words);
            if ($wc != scalar(@t_words)) {
                $self->myDie("wrong input");
            }
            if ($self->CHECK_WORD_LENGTHS eq "yes") {
                if (abs((length $s)- (length $t))>5) {
                    binmode(STDOUT, ":utf8");
                    print "DIFFERENT LENGTHS\n";
                    print "LEFT:\n[";
                    print $s;
                    print "]\n".length($s)."\n";
                    print "RIGHT:\n[";
                    print $t;
                    print "]\n".length($t)."\n";   
                    $self->myDie("different lengths");
                }
            }
            print $outf join(" ", map { "$_-$_" } 0 .. $wc - 1);
            print $outf "\n";
        }
        close $inf or $self->myDie("cannot close in");
        close $outf or $self->myDie("cannot close out");
    }
  



}


1;



