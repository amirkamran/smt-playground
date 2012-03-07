#!/usr/bin/perl -w

# Sample De-Tokenizer
# written by Josh Schroeder, based on code by Philipp Koehn
# modified by Dan Zeman (v1.1: language-dependent directed quotation marks)

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
use strict;

my $language = 'en';
my $QUIET = 0;
my $HELP = 0;

while (@ARGV) {
	$_ = shift;
	/^-l$/ && ($language = shift, next);
	/^-q$/ && ($QUIET = 1, next);
	/^-h$/ && ($HELP = 1, next);
}

if ($HELP) {
	print "Usage ./detokenizer.pl (-l [en|de|...]) < tokenizedfile > detokenizedfile\n";
	exit;
}
if (!$QUIET) {
	print STDERR "Detokenizer Version 1.1\n";
	print STDERR "Language: $language\n";
    die("Unknown language") unless($language);
}

while(<STDIN>) {
	if (/^<.+>$/ || /^\s*$/) {
		#don't try to detokenize XML/HTML tag lines
		print $_;
	}
	else {
		print &detokenize($_);
	}
}

sub detokenize {
    my($text) = @_;

    # Quotes, apostrophes and characters mistakable for them
    my $adq = '"'; # ascii double quote: APOSTROPHE
    my $asq = "'"; # ascii single quote: QUOTATION MARK
    my $acu = "\x{B4}"; # ACUTE ACCENT
    my $gra = '`'; # GRAVE ACCENT
    my $llt = "\x{AB}"; # less less than: LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    my $ggt = "\x{BB}"; # greater greater than: RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    my $sh6 = "\x{2018}"; # horní 6: LEFT SINGLE QUOTATION MARK
    my $sh9 = "\x{2019}"; # horní 9: RIGHT SINGLE QUOTATION MARK
    my $sd9 = "\x{201A}"; # dolní 9: SINGLE LOW-9 QUOTATION MARK
    my $shp = "\x{201B}"; # horní stranově převrácená 9: SINGLE HIGH-REVERSED-9 QUOTATION MARK
    my $h66 = "\x{201C}"; # horní 66: LEFT DOUBLE QUOTATION MARK
    my $h99 = "\x{201D}"; # horní 99: RIGHT DOUBLE QUOTATION MARK
    my $d99 = "\x{201E}"; # dolní 99: DOUBLE LOW-9 QUOTATION MARK
    my $hpp = "\x{201F}"; # horní stranově převrácené 99: DOUBLE HIGH-REVERSED-9 QUOTATION MARK
    my $pri = "\x{2032}"; # PRIME (určeno pro matematiku, ale zneužitelné jako apostrof)
    my $dpri = "\x{2033}"; # DOUBLE PRIME
    my $tpri = "\x{2034}"; # TRIPLE PRIME
    my $rpri = "\x{2035}"; # REVERSED PRIME
    my $rdpri = "\x{2036}"; # REVERSED DOUBLE PRIME
    my $rtpri = "\x{2037}"; # REVERSED TRIPLE PRIME
    # Other special characters
    my $slash = '/'; # SOLIDUS; proměnná se hodí do regulárních výrazů, které jsou lomítky ohraničené, protože znemožní interpretaci lomítka jako konce výrazu
    my $hash = '#'; # NUMBER SIGN; proměnná se hodí pro jistotu, kdyby si snad regulární výraz nebo syntax highlighting myslel, že jde o komentář
    my $lexcl = "\x{A1}"; # INVERTED EXCLAMATION MARK (španělština)
    my $lqest = "\x{BF}"; # INVERTED QUESTION MARK (španělština)
    my $shyph = "\x{AD}"; # SOFT HYPHEN (ví bůh, co to je)
    my $ndash = "\x{2013}"; # EN DASH
    my $mdash = "\x{2014}"; # EM DASH
    my $ell = "\x{2026}"; # HORIZONTAL ELLIPSIS
    # The following characters must be escaped by backslash even in variables because otherwise they have special meaning for the regular expression interpreter.
    # Do not use these variables elsewhere than in regular expressions unless printing of the escaping backslash is desired.
    my $lrb = "\\("; # LEFT PARENTHESIS
    my $rrb = "\\)"; # RIGHT PARENTHESIS
    my $lsb = "\\["; # LEFT SQUARE BRACKET
    my $rsb = "\\]"; # RIGHT SQUARE BRACKET
    my $lcb = "\\{"; # LEFT CURLY BRACKET
    my $rcb = "\\}"; # RIGHT CURLY BRACKET
    my $dot = "\\."; # FULL STOP
    my $plus = "\\+"; # PLUS SIGN
    my $hyph = "\\-"; # HYPHEN-MINUS
    my $minus = "\x{2212}"; # MINUS SIGN
    my $ast = "\\*"; # ASTERISK
    my $excl = "\\!"; # EXCLAMATION MARK
    my $qest = "\\?"; # QUESTION MARK
    my $at = "\\\@"; # COMMERCIAL AT
    my $bslash = "\\\\"; # REVERSE SOLIDUS

    chomp($text);
    # The code later on attempts at handling of undirected quotes based on their number (even/odd).
    # Here we process directed Unicode quotes, which is an easier task, provided we know the language correctly.
    my ($ql, $qr);
    # Spanish and French: double angle quotation marks
    if($language =~ m/^(es|fr)$/) {
        $ql = $llt;
        $qr = $ggt;
    }
    # Czech and German: low 99 left, high 66 right
    elsif($language =~ m/^(cs|de)$/) {
        $ql = $d99;
        $qr = $h66;
    }
    # Default taken from English: high 66 left, high 99 right
    else {
        $ql = $h66;
        $qr = $h99;
    }
    $text =~ s/([$ql$lrb$lsb$lcb$lexcl$lqest])\s+/$1/g;
    $text =~ s/\s+([$rcb$rsb$rrb$qr,;:$excl$qest])/$1/g;
    s/$qr\s+\./$qr./g;
    # Unify three-dot ellipses.
    s/\.\.\.+/$ell/g;
    # Note that we may want to make this operation optional.
    # If it is guaranteed that all quotation marks are directed and thus use the Unicode points,
    # then it is guaranteed that all apostrophes are mere contractions as in English "don't" or French "l'ordre", "d'un", "n'est"...
    # However, if we detokenize text where apostrophe can also be used as a single quotation mark, this approach will not work!
    $text =~ s/\s+'\s+/'/g;
    if($language eq 'fr')
    {
        $text =~ s/\s*-\s*t\s*-\s*(il|on)/-t-$1/g;
        $text =~ s/\s*-\s*(il|vous|ce)/-$1/g;
    }

    # DZ: The original detokenizing code starts here.
    $text = " $text ";

	my $word;
	my $i;
	my @words = split(/ /,$text);
	$text = "";
	my %quoteCount =  ("\'"=>0,"\""=>0);
	my $prependSpace = " ";
	for ($i=0;$i<(scalar(@words));$i++) {		
		if ($words[$i] =~ /^[\p{IsSc}\(\[\{\¿\¡]+$/) {
			#perform right shift on currency and other random punctuation items
			$text = $text.$prependSpace.$words[$i];
			$prependSpace = "";
		} elsif ($words[$i] =~ /^[\,\.\?\!\:\;\\\%\}\]\)]+$/){
			#perform left shift on punctuation items
			$text=$text.$words[$i];
			$prependSpace = " ";
		} elsif (($language eq "en") && ($i>0) && ($words[$i] =~ /^[\'][\p{IsAlpha}]/) && ($words[$i-1] =~ /[\p{IsAlnum}]$/)) {
			#left-shift the contraction for English
			$text=$text.$words[$i];
			$prependSpace = " ";
		}  elsif (($language eq "fr") && ($i<(scalar(@words)-2)) && ($words[$i] =~ /[\p{IsAlpha}][\']$/) && ($words[$i+1] =~ /^[\p{IsAlpha}]/)) {
			#right-shift the contraction for French
			$text = $text.$prependSpace.$words[$i];
			$prependSpace = "";
		} elsif ($words[$i] =~ /^[\'\"]+$/) {
			#combine punctuation smartly
			if (($quoteCount{$words[$i]} % 2) eq 0) {
				if(($language eq "en") && ($words[$i] eq "'") && ($i > 0) && ($words[$i-1] =~ /[s]$/)) {
					#single quote for posesssives ending in s... "The Jones' house"
					#left shift
					$text=$text.$words[$i];
					$prependSpace = " ";
				} else {
					#right shift
					$text = $text.$prependSpace.$words[$i];
					$prependSpace = "";
					$quoteCount{$words[$i]} = $quoteCount{$words[$i]} + 1;

				}
			} else {
				#left shift
				$text=$text.$words[$i];
				$prependSpace = " ";
				$quoteCount{$words[$i]} = $quoteCount{$words[$i]} + 1;

			}
			
		} else {
			$text=$text.$prependSpace.$words[$i];
			$prependSpace = " ";
		}
	}
	
	# clean up spaces at head and tail of each line as well as any double-spacing
	$text =~ s/ +/ /g;
	$text =~ s/\n /\n/g;
	$text =~ s/ \n/\n/g;
	$text =~ s/^ //g;
	$text =~ s/ $//g;
	
	#add trailing break
	$text .= "\n" unless $text =~ /\n$/;

	return $text;
}
