use MooseX::Declare;

class Seeds::IdentAlign with (Roles::GeneralAlign){
    use HasDefvar;

    has_defvar 'CHECK_WORD_LENGTHS' => (help=>'yes if seed should also check word lengths', default=>'yes');

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

        ident_align($inf, $outf);
    }
           

    method ident_align(FileHandle $inf, FileHandle $outf) {
        while (my $line=<$inf>) {
            my ($s, $t) = split (/\t/, $line) or $self->myDie("wrong iput");
            my @s_words = split(/ /,$s);
            my @t_words = split(/ /,$t);
            my $wc = scalar(@s_words);
            if ($wc != scalar(@t_words)) {
                $self->myDie("wrong input");
            }
            if ($self->CHECK_WORD_LENGTHS eq "yes") {
                if (length $s!= length $t) {
                    $self->myDie("different lengts");
                }
            }
            print $outf join(" ", map { "$_-$_" } 0 .. $wc - 1);
        }
    }
  



}


1;



