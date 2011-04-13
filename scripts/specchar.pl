#!/usr/bin/perl
# Analyzuje textový korpus s ohledem na různé zvláštní znaky, např. různé druhy uvozovek.
# Předpokládá, že korpus je netokenizovaný. Případné mezery kolem interpunkce hrají roli.
# Copyright © 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

sub usage
{
    print STDERR ("Usage: specchar.pl -l language < original-corpus > modified-corpus\n");
    print STDERR ("    Corpus is untokenized, one sentence (segment) per line.\n");
    print STDERR ("    Language is identified by ISO 639-1 code.\n");
    print STDERR ("    Known languages: en, es.\n");
}

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
use Getopt::Long;
use HTML::Entities;

# Úpravy uvozovek jsou jazykově závislé.
GetOptions('language=s' => \$jazyk);
unless($jazyk =~ m/^(en|es)$/i)
{
    usage();
    die("Unknown language '$jazyk'.\n");
}



BEGIN
{
    # Uvozovky, apostrofy a znaky s nimi zaměnitelné
    $adq = '"'; # ascii double quote: APOSTROPHE
    $asq = "'"; # ascii single quote: QUOTATION MARK
    $acu = "\x{B4}"; # ACUTE ACCENT
    $gra = '`'; # GRAVE ACCENT
    $llt = "\x{AB}"; # less less than: LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    $ggt = "\x{BB}"; # greater greater than: RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    $sh6 = "\x{2018}"; # horní 6: LEFT SINGLE QUOTATION MARK
    $sh9 = "\x{2019}"; # horní 9: RIGHT SINGLE QUOTATION MARK
    $h66 = "\x{201C}"; # horní 66: LEFT DOUBLE QUOTATION MARK
    $h99 = "\x{201D}"; # horní 99: RIGHT DOUBLE QUOTATION MARK
    $d99 = "\x{201E}"; # dolní 99: DOUBLE LOW-9 QUOTATION MARK
    # Další zvláštní znaky
    $slash = '/'; # SOLIDUS; proměnná se hodí do regulárních výrazů, které jsou lomítky ohraničené, protože znemožní interpretaci lomítka jako konce výrazu
    $hash = '#'; # NUMBER SIGN; proměnná se hodí pro jistotu, kdyby si snad regulární výraz nebo syntax highlighting myslel, že jde o komentář
    $lexcl = "\x{A1}"; # INVERTED EXCLAMATION MARK (španělština)
    $lqest = "\x{BF}"; # INVERTED QUESTION MARK (španělština)
    $shyph = "\x{AD}"; # SOFT HYPHEN (ví bůh, co to je)
    $ndash = "\x{2013}"; # EN DASH
    $mdash = "\x{2014}"; # EM DASH
    $ell = "\x{2026}"; # HORIZONTAL ELLIPSIS
    # Tyto znaky musíme i do proměnných ukládat zneškodněné backslashem, protože jinak mají zvláštní význam pro interpret regulárních výrazů.
    # Jinde než v regulárních výrazech tyto proměnné nepoužívat, pokud nechceme před daným znakem vypsat i jeho backslash.
    $lrb = "\\("; # LEFT PARENTHESIS
    $rrb = "\\)"; # RIGHT PARENTHESIS
    $lsb = "\\["; # LEFT SQUARE BRACKET
    $rsb = "\\]"; # RIGHT SQUARE BRACKET
    $lcb = "\\{"; # LEFT CURLY BRACKET
    $rcb = "\\}"; # RIGHT CURLY BRACKET
    $dot = "\\."; # FULL STOP
    $plus = "\\+"; # PLUS SIGN
    $hyph = "\\-"; # HYPHEN-MINUS
    $ast = "\\*"; # ASTERISK
    $excl = "\\!"; # EXCLAMATION MARK
    $qest = "\\?"; # QUESTION MARK
    $bslash = "\\\\"; # REVERSE SOLIDUS
}



while(<>)
{
    # Odstranit zalomení řádku.
    s/\r?\n$//;
    # Odstranit přebytečné mezery (např. v anglickém europarlu se objevují).
    s/^\s+//;
    s/\s+$//;
    s/\s+/ /g;
    # Obsahuje vstup XML entity? Typicky nechceme žádné kromě &amp;, &lt;, &gt; a &pipe;. Např. &quot; je na závadu.
    decode_entities($_);
    # Zkontrolovat, že HTML::Entities umí odstranit všechny entity.
    # Je ale taky možné, že text obsahuje řetězec, který vypadá jako entita, ale není, např. "S&D;".
    while(s/(&\#?[A-Za-z0-9]+;)//)
    {
        print STDERR ("Nepodařilo se dekódovat entitu $1.\n");
    }
    # Dvě po sobě jdoucí pomlčky považujeme za snahu napsat dlouhou m-pomlčku.
    # Nerozpoznáváme žádnou podobnou pomůcku pro n-pomlčku, tu by musel autor textu napsat přímo.
    s/--/$mdash/g;
    # Najít všechny uvozovky na řádku a odhadnout, zda jsou počáteční, nebo koncové.
    $_ = usmernit_uvozovky($_, $jazyk);
    # Odstranit přebytečné (chybné) mezery kolem interpunkce.
    # Mezera určitě nemá být za počátečními závorkami a uvozovkami.
    # Mezera určitě nemá být před koncovými závorkami a uvozovkami a dále před čárkou, středníkem, dvojtečkou, vykřičníkem a otazníkem.
    # Nemůžeme s jistotou říct, že mezera nemá být před tečkou, protože výpustka ("...") může mít mezery z obou stran.
    # Nicméně, když už teď máme orientované uvozovky, můžeme alespoň říct, že mezi koncovou uvozovkou a tečkou mezera být nemá.
    # Také nemáme dostatečně spolehlivé pravidlo pro mezery kolem pomlček.
    s/([$q0$lrb$lsb$lcb$lexcl$lqest])\s+/$1/g;
    s/\s+([$rcb$rsb$rrb$q1,;:$excl$qest])/$1/g;
    s/$q1\s+\./$q1./g;
    # Sjednotit třítečkové výpustky.
    s/\.\.\.+/$ell/g;
    # Vypsat opravenou větu na standardní výstup.
    print("$_\n");
}



###############################################################################
# PODPROGRAMY
###############################################################################



#------------------------------------------------------------------------------
# Vrátí dvojici znaků pro sjednocené počáteční a koncové uvozovky daného
# jazyka.
#------------------------------------------------------------------------------
sub zjistit_znaky_uvozovek_pro_jazyk
{
    my $jazyk = shift; # kód jazyka
    my $q0; # znak počáteční uvozovky
    my $q1; # znak koncové uvozovky
    # Španělština: dvojité menšítko nalevo, dvojité většítko napravo.
    if($jazyk eq 'es')
    {
        $q0 = $llt;
        $q1 = $ggt;
    }
    # Čeština: spodní 99 vlevo, horní 66 vpravo.
    elsif($jazyk eq 'cs')
    {
        $q0 = $d99;
        $q1 = $h66;
    }
    # Default podle angličtiny: horní 66 vlevo, horní 99 vpravo.
    else
    {
        $q0 = $h66;
        $q1 = $h99;
    }
    return ($q0, $q1);
}



#------------------------------------------------------------------------------
# Sjednotí znak pro apostrof s funkcí výpustky, nikoli uvozovky (např.
# v anglickém "don't"). Cílem je, aby všechny výskyty s funkcí výpustky
# používaly pouze tento znak. Není zaručeno, že se tento znak nevyskytuje i
# s funkcí uvozovky.
#------------------------------------------------------------------------------
sub sjednotit_vypustkovy_apostrof
{
    my $veta = shift;
    # Příležitostně se objevuje samostatný acute accent (\x{B4}) a téměř vždy je použit místo apostrofu.
    # Např. v news-commentary-v6.es-en.es je to 20 vět a ani jednou se tam nehovoří o diakritickém znaménku.
    # Někdy se dokonce těsně vedle sebe objevuje apostrof i accute accent se stejnou funkcí: "L´Elisir D'Amore".
    # Riskneme tedy, že to velmi výjimečně může být chyba, a nahradíme všechny accute accenty apostrofy.
    # Samostatný grave accent obklopený alfanumerickými znaky je pravděpodobně také použit místo výpustkového apostrofu: "Dell`Alba".
    # Pokud má ale z jedné strany mezeru, musíme být opatrnější, může to být pokus o náhradu počáteční jednoduché anglické uvozovky.
    # Totéž platí pro RIGHT SINGLE QUOTATION MARK (\x{2019}).
    # Výjimečně též LEFT SINGLE QUOTATION MARK (\x{2018}).
    $veta =~ s/(\w)[$gra$acu$sh6$sh9](\w)/$1'$2/g;
    return $veta;
}



#------------------------------------------------------------------------------
# Odstraní konkrétní jednorázové chyby pozorované v datech, které se
# neodvažujeme zobecnit. Jsou pochopitelně závislé nejen na jazyku, ale dokonce
# na konkrétním datovém souboru, avšak vzhledem k jejich jedinečnosti nemusíme
# kontrolovat, zda právě s dotyčným souborem pracujeme. I když by se tím možná
# trochu zrychlilo zpracování souboru.
#------------------------------------------------------------------------------
sub odstranit_jednorazove_chyby
{
    my $veta = shift;
    # europarl-v6.es-en.es
    $veta =~ s/\x{AB}'((Turkish|Indice)[\s\w]+?)\x{BB}/\x{AB}$1\x{BB}/g;
    $veta =~ s/m($asq$asq|$acu$acu)as allá/más allá/g;
    # (re)"[!]lanzamiento"[K1]
    $veta =~ s/\(re\)"lanzamiento"/(re)${llt}lanzamiento${ggt}/g;
    $veta =~ s/siguientes:"\./siguientes:\x{BB}./g;
    $veta =~ s-militar/"civil"-militar/\x{AB}civil\x{BB}-g;
    # europarl-v6.es-en.en
    $veta =~ s/read: \.\.\.'welcome the bank/read: '... welcome the bank/g;
    $veta =~ s/\?in fact, fifty-four \\u8722\\'2d but/in fact, fifty-four, but/g;
    $veta =~ s-military/'civil'-military/\x{201C}civil\x{201D}-g;
    $veta =~ s/specify among other things:'\./specify among other things:/g;
    $veta =~ s/Permanent Representatives$acu$sh9 committee/Permanent Representatives' committee/g;
    $veta =~ s/\(re\)'launch'/(re)${h66}launch${h99}/g;
    $veta =~ s/"' may' provision'/${h66}${h66}may${h99} provision${h99}/g;
    $veta =~ s/'humanitarian war'\(!!!\),/${h66}humanitarian war${h99} (!!!),/g;
    # news-commentary-v6.es-en.en
    $veta =~ s/commerce"\(xiahai\)to/commerce" (xiahai) to/g;
    $veta =~ s/as "excellent"\(qualifying/as ${h66}excellent${h99} (qualifying/g;
    $veta =~ s/ \x{E2}\x{20AC}" / $mdash /g;
    $veta =~ s/America\x{E2}\x{20AC}\x{2122}s/America's/g;
    $veta =~ s/leaders$shyph'/leaders'$shyph/g;
    return $veta;
}



#------------------------------------------------------------------------------
# Rozhodne, které uvozovky jsou počáteční a které koncové.
# Vrátí upravenou větu, která obsahuje pouze orientované uvozovky.
#------------------------------------------------------------------------------
sub usmernit_uvozovky
{
    my $veta = shift;
    my $jazyk = shift;
    my $q = "[$acu$gra$asq$adq$llt$ggt\x{2018}-\x{201F}]";
    # Na výstupu chceme počáteční (q0) a koncové (q1) uvozovky daného jazyka sjednotit na následujících znacích:
    my ($q0, $q1) = zjistit_znaky_uvozovek_pro_jazyk($jazyk);
    # Nahradit TeXové uvozovky normálními.
    $veta =~ s/``(.*?)''/$q0$1$q1/g;
    # Výjimečně se objevuje taky ''tohle'', ale všechna naše pravidla počítají s jednoznakovými uvozovkami, takže převést.
    $veta =~ s/''/"/g;
    $veta =~ s/``/$q0/g;
    # Nahradit `tohle' orientovanými uvozovkami.
    # Není asi úplně bezpečné dělat to jednoduchým regulárním výrazem, ale alespoň v angličtině to nutně musíme pochytat
    # kvůli odlišení od výpustkového apostrofu, zejména toho na konci slova v genitivu plurálu.
    if($jazyk eq 'en')
    {
        $veta =~ s/\`(\w.*?\w)'/$q0$1$q1/g;
        # V europarl-v6.es-en.en se objevuje genitiv odtržený od hlavní části slova s apostrofem.
        # Přilepením zpět jednak dosáhneme správnějšího pravopisu, jednak usnadníme identifikaci apostrofu jako neuvozovkového.
        $veta =~ s/(\w)'\s+s(,?)\s+/$1's$2 /g;
    }
    # Sjednotit znak pro apostrof s funkcí výpustky.
    $veta = sjednotit_vypustkovy_apostrof($veta);
    # Bez mezery po obou stranách se může vyskytnout apostrof s funkcí výpustky, nikoli uvozovky.
    # Pokud se takto vyskytne uvozovka, jde zřejmě o chybu a na jedné straně měla být mezera.
    # Nevíme však na které, proto přidáme mezery po obou stranách a necháme řešení na pořadí uvozovky, viz níže.
    # \x{B7} je MIDDLE DOT a ve španělštině se objevuje, i když asi často omylem.
    $veta =~ s/([\w\x{B7}\-$ndash$mdash,;:\.$ell\!\?])"([\w\x{B7}])/$1 " $2/g;
    # Španělské párové otazníky mají být buď oba uvnitř uvozovek, nebo oba vně, ale nemůže to být křížem:
    # "\x{BF}Tiene cura?" ... OK
    # \x{BF} ... tiene "cura"? ... OK
    # \x{BF}"Tiene cura?" ... špatně
    $veta =~ s/\x{BF}"([^"]+)\?"/"\x{BF}$1?"/g;
    # V některých případech zřejmě z textu vypadl výraz uvnitř uvozovek a dvě neutrální uvozovky se tak dostaly k sobě.
    # Oddělit je mezerou, což povede k nouzové identifikaci pomocí pořadí.
    $veta =~ s/\s"",\s/ " " , /g;
    $veta =~ s/\s""\s/ " " /g;
    $veta =~ s/\s$sh6$sh9\s/ $q0$q1 /g;
    # Konkrétní jednorázové chyby. Neodvažuji se je zatím příliš zobecnit.
    $veta = odstranit_jednorazove_chyby($veta);
    # Po provedení všech oprav nad celou větou rozebrat větu na znaky a pracovat dále s nimi.
    my @znaky = split(//, $veta);
    # Váha možnosti, že i-tý znak je počáteční, resp. koncová uvozovka.
    my @pocatecni;
    my @koncova;
    # Váha možnosti, že dotyčný znak nemá funkci uvozovky (např. apostrof v anglickém "don't").
    my @zadna;
    my @rozhodnuto;
    my $vse_rozhodnuto = 1;
    for(my $i = 0; $i<=$#znaky; $i++)
    {
        # Je tento znak uvozovka?
        if($znaky[$i] =~ m/$q/)
        {
            # Pravidla a heuristiky pro uvozovky:
            # Jestliže znak uvozovky odpovídá aktuálně nastavenému cílovému znaku pro orientovanou uvozovku, věřit jeho orientaci.
            # Na orientaci orientovaných uvozovek, které nejsou aktuálně nastavené jako cílové, nebudeme brát zřetel.
            # Důvodem je, že tentýž znak může mít různou orientaci v různých jazycích (např. anglická počáteční je česká koncová).
            # U uvozovek z jiného než aktuálního jazyka nemáme jistotu, jak si jejich orientaci vykládal ten, kdo je do textu vložil.
            if($znaky[$i] eq $q0)
            {
                $pocatecni[$i] += 10;
            }
            elsif($znaky[$i] eq $q1)
            {
                $koncova[$i] += 10;
            }
            # Nicméně, v některých jazycích je ještě k dispozici alternativní pár orientovaných uvozovek.
            # Bohužel, stává se, že jsou použity i neorientovaně, např.
            #  to be known as \x{2019}Ulysses\x{2019}.
            # místo
            #  to be known as \x{2018}Ulysses\x{2019}.
            # nebo
            #  to be known as 'Ulysses'.
            # Proto jim dáme nejmenší možnou nenulovou váhu.
            elsif($jazyk eq 'en')
            {
                if($znaky[$i] eq $sh6) # LEFT SINGLE QUOTATION MARK
                {
                    $pocatecni[$i]++;
                }
                elsif($znaky[$i] eq $sh9) # RIGHT SINGLE QUOTATION MARK
                {
                    $koncova[$i]++;
                }
            }
            # Uvozovka na začátku řádku => počáteční.
            if($i==0 ||
               $i==1 && $znaky[$i-1] =~ m/$q/)
            {
                $pocatecni[$i] += 2;
            }
            # Uvozovka na konci řádku => koncová.
            if($i==$#znaky ||
               $i==$#znaky-1 && $znaky[$i+1] =~ m/$q/)
            {
                $koncova[$i] += 2;
            }
            # U dalších pravidel chceme kontrolovat sousedy vlevo a vpravo, takže potřebujeme mít jistotu, že sousedé existují.
            if($i>0 && $i<$#znaky)
            {
                # Apostrofy se vyskytují také jako znak výpustky.
                # Francouzský člen "l'" se může vyskytnout díky citacím i v jiných jazycích.
                # Podobně předložka "d'".
                # Nebudeme zkoumat, zda je před "l" mezera, mohl by to být také začátek řádku, případně nějaká stažená předložka ("dell'"?)
                # A navíc bychom nejdřív museli ověřit, že se nacházíme dostatečně daleko od začátku řádku.
                # Obecně: možná můžeme každý apostrof, který má z obou stran alfanumerický znak, považovat za výpustku.
                # Výpustkový apostrof také může být před čísly označujícími letopočet: "recapitular el "'68"?"
                # Ojediněle se objevil také mezi písmenem a uvozovkou: "del'\x{AB}Estonia\x{BB}"
                # V angličtině za výpustkový považujeme i apostrof na konci slova, které končí písmenem "s". Označuje genitiv plurálu: "with taxpayers' money".
                # Genitiv může také dostat zkratka ukončená tečkou:
                # Speer Jr.'s commission
                # Berlusconi and Co.'s attacks
                # Genitiv může také dostat složené podstatné jméno následované zkratkou v závorce:
                # Union for Europe of the Nations Group (UEN)'s Amendment
                # news-commentary-v6.es-en.en
                # m/"'68(\.| generation)"/
                # Tohle nejde dostatečně zobecnit, protože by to taky mohly být vnořené uvozovky.
                # Potřebovali bychom kombinaci indexového přístupu k jednotlivým znakům a regulárních výrazů.
                # Třeba pro každý znak udržovat levý kontext od začátku řádku a pravý kontext do konce řádku.
                # Nad těmito kontexty bychom pak mohli pouštět regulární výrazy.
                # To zatím nemáme, tak alespoň zavedeme tvrdé pravidlo pro '68.
                # Takové pravidlo by spíše patřilo do funkce odstranit_jednorazove_chyby(), ale tam ho dát nemůžeme,
                # protože tato funkce umí pouze substituce regulárních výrazů, ale nemůže konkrétnímu znaku upravit váhu značky.
                if($i<=$#znaky-2 && $znaky[$i] eq "'" && $znaky[$i+1] eq '6' && $znaky[$i+2] eq '8')
                {
                    $zadna[$i] += 10;
                }
                elsif($znaky[$i-1] =~ m/\w/ && $znaky[$i] eq "'" && $znaky[$i+1] =~ m/\w/ ||
                   $znaky[$i-1] =~ m/[\s"]/ && $znaky[$i] eq "'" && $znaky[$i+1] =~ m/\d/ ||
                   $i>=3 && $znaky[$i-3] eq 'd' && $znaky[$i-2] eq 'e' && $znaky[$i-1] eq 'l' && $znaky[$i] eq "'" && $znaky[$i+1] eq "\x{AB}" ||
                   $i>=2 && $znaky[$i-2] =~ m/\w/ && $znaky[$i-1] eq '.' && $znaky[$i] eq "'" && $znaky[$i+1] eq 's' ||
                   $jazyk eq 'en' && $znaky[$i-1] eq 's' && $znaky[$i] eq "'" && $znaky[$i+1] =~ m/[\s$shyph]/ ||
                   $jazyk eq 'en' && $znaky[$i-1] eq ')' && $znaky[$i] eq "'" && $znaky[$i+1] eq 's')
                {
                    $zadna[$i] += 2;
                }
                else
                {
                    # Nalevo od počáteční uvozovky může být mezera, levá nebo neutrální interpunkce.
                    # Obrácený vykřičník a otazník může uvozovce i předcházet: \x{BF}"Perderán" los Estados Unidos a América Latina?
                    my $predq0 = "[\\s$hyph$ndash$mdash$slash$lrb$lsb$lcb$lexcl$lqest:]";
                    # Napravo od počáteční uvozovky může být alfanumerický znak, levá nebo neutrální interpunkce.
                    # Tečka je neutrální, může být na začátku přímé řeči jako součást výpustky ("...").
                    # Taky může následovat výpustkový apostrof ("el "'68""). To bychom ale měli kontrolovat, zda už byl identifikován jako výpustkový.
                    # Dvojkříž za počáteční uvozovkou se vyskytl v news-commentary-v6.es-en.es.
                    my $poq0 = "[\\w$hyph$lrb$lsb$lcb$lexcl$lqest$dot$ell$asq$hash$plus]";
                    # Nalevo od koncové uvozovky může být alfanumerický znak, pravá nebo neutrální interpunkce.
                    # \x{B7} je "MIDDLE DOT". Jednou se mi vyskytla před koncovou uvozovkou, ale byl to překlep.
                    my $predq1 = "[\\w$hyph$rrb$rsb$rcb$excl$qest$dot$ell,;\x{B7}$asq%$plus]";
                    # Napravo od koncové uvozovky může být mezera, pravá nebo neutrální interpunkce.
                    # (Poznámka: v češtině se většinou tečka za větou schová dovnitř uvozovek, ale ve španělských datech to mám častěji obráceně.)
                    # U vnořených uvozovek může následovat výpustka, např. "nunca se enteró de que hubo un 'baby boom'...".
                    my $poq1 = "[\\s$hyph$ndash$mdash$rrb$rsb$rcb$excl$qest$dot$ell,;:$asq$adq$ggt$slash]";
                    # Uvozovka obklopená kontextem počáteční uvozovky asi bude počáteční.
                    if($znaky[$i-1] =~ m/$predq0/ &&
                       $znaky[$i+1] =~ m/$poq0/)
                    {
                        $pocatecni[$i] += 2;
                    }
                    # Uvozovka obklopená kontextem koncové uvozovky asi bude koncová.
                    if($znaky[$i-1] =~ m/$predq1/ &&
                       $znaky[$i+1] =~ m/$poq1/)
                    {
                        $koncova[$i] += 2;
                    }
                    # Mohou se vyskytnout i vnořené uvozovky, např. bien!'".
                    # Nikde není zaručeno, která uvozovka je vnitřní (klidně může být uvnitř dvojitá a venku jednoduchá).
                    # U vnořených uvozovek může za obyčejnou uvozovkou následovat španělská koncová: "Espero poder hacerlo del mismo modo"\x{BB}."
                    if($i<=$#znaky-2)
                    {
                        if($znaky[$i-1] =~ m/$predq0/ &&
                           $znaky[$i] =~ m/$q/ &&
                           $znaky[$i+1] =~ m/$q/ &&
                           $znaky[$i+2] =~ m/$poq0/)
                        {
                            $pocatecni[$i]++;
                            $pocatecni[$i+1]++;
                        }
                        if($znaky[$i-1] =~ m/$predq1/ &&
                           $znaky[$i] =~ m/$q/ &&
                           $znaky[$i+1] =~ m/$q/ &&
                           $znaky[$i+2] =~ m/$poq1/)
                        {
                            $koncova[$i]++;
                            $koncova[$i+1]++;
                        }
                    }
                    # Zvláštní případy:
                    # Pokud je za uvozovkou (chybně) mezera, ale před uvozovkou je počáteční závorka, je také uvozovka počáteční.
                    # Stejně tak dvojtečku před uvozovkou považujeme za důkaz počátečnosti uvozovky.
                    if($znaky[$i-1] =~ m/[\(:]/ &&
                       $znaky[$i+1] =~ m/\s/)
                    {
                        $pocatecni[$i] += 2;
                    }
                    # Pokud je před uvozovkou (chybně) mezera, ale za uvozovkou je koncová závorka, je také uvozovka koncová.
                    # Stejně tak dvojtečku nebo otazník za uvozovkou považujeme za důkaz koncovosti uvozovky.
                    if($znaky[$i-1] =~ m/\s/ &&
                       $znaky[$i+1] =~ m/[\):\?]/)
                    {
                        $koncova[$i] += 2;
                    }
                    # Pokud uvozovka chybně nemá mezeru ze žádné strany, ale před ní je tečka a za ní počáteční závorka,
                    # považujeme ji za koncovou jako v tomto příkladu:
                    # ... en el título de su portada: "Grow, dammit, grow."(\x{BF}Maldita sea! crece).
                    if($znaky[$i-1] eq '.' &&
                       $znaky[$i+1] eq '(')
                    {
                        $koncova[$i]++;
                    }
                    # europarl-v6.es-en.en
                    # Opakovaně se objevují prázdné dvojice jednoduchých uvozovek, mezi nimiž byl zjevně vymazán nějaký citát.
                    # Jejich výskyt těsně vedle sebe mate naše pravidla, podle kterých by mohlo jít i o vnořené uvozovky.
                    if($jazyk eq 'en' &&
                       $i<=$#znaky-2 &&
                       $znaky[$i-1] =~ m/\s/ &&
                       $znaky[$i] eq $sh6 &&
                       $znaky[$i+1] eq $sh9 &&
                       $znaky[$i+2] eq '.')
                    {
                        $pocatecni[$i] += 10;
                        $koncova[$i+1] += 10;
                    }
                    # Pokud jsou vedle sebe dvě neutrální uvozovky, může jít o vnořené uvozovky, ale nevíme, zda počáteční, nebo koncové.
                    # U kombinace "' je pravděpodobné, že apostrof je vnitřní, ale jisté to asi není a u jiných kombinací žádné vodítko nemáme.
                    # Také může jít o překlep (místo dvou uvozovek tam měla být jen jedna).
                    # Řešení: Pokud má levá uvozovka vedle sebe mezeru a pravá alfanumerický znak, považujeme je obě za počáteční.
                    # europarl-v6.es-en.es:
                    # no me puedo resistir a la tentación de desafiar a los intérpretes exclamando ""\x{A1}Curioso y requetecurioso!\x{201D} gritó Alicia".
                    if($i<$#znaky-1 &&
                       $znaky[$i-1] =~ m/\s/ &&
                       $znaky[$i] =~ m/["']/ &&
                       $znaky[$i+1] =~ m/["']/ &&
                       $znaky[$i+2] =~ m/[\w\x{A1}\x{BF}]/)
                    {
                        $pocatecni[$i]++;
                        $pocatecni[$i+1]++;
                    }
                    if($i>1 &&
                       $znaky[$i-2] =~ m/\w/ &&
                       $znaky[$i-1] =~ m/["\x{201D}]/ &&
                       $znaky[$i] eq '"' &&
                       $znaky[$i+1] =~ m/[,\.]/)
                    {
                        $koncova[$i-1]++;
                        $koncova[$i]++;
                    }
                    # Ukazuje se, že ve španělském textu (europarl) se objevují anglické pravé uvozovky ve funkci levých:
                    # El titular dice: \x{AB}\x{201D}Los Estados que ... abandonar la UE\x{201D}, dice Prodi.\x{BB}
                    if($znaky[$i-1] eq "\x{AB}" &&
                       $znaky[$i] eq "\x{201D}")
                    {
                        $pocatecni[$i]++;
                    }
                    if($znaky[$i-1] eq '"' &&
                       $znaky[$i] eq '"' &&
                       $znaky[$i+1] eq '.')
                    {
                        $koncova[$i]++;
                    }
                    # europarl-v6.es-en.en
                    # Pozorované dvojice vnořených uvozovek:
                    # \x{201D}'
                }
            }
            # Už víme, jaká je to uvozovka?
            $rozhodnuto[$i] =
                $zadna[$i]>$pocatecni[$i] && $zadna[$i]>$koncova[$i] ||
                $pocatecni[$i]>$koncova[$i] && $pocatecni[$i]>$zadna[$i] ||
                $koncova[$i]>$pocatecni[$i] && $koncova[$i]>$zadna[$i];
            if(!$rozhodnuto[$i])
            {
                # Typ uvozovky se nepodařilo rozhodnout.
                # Zapamatovat si, že došlo k problému. Po projití celé věty ji vypíšeme na výstup k další analýze.
                $vse_rozhodnuto = 0;
            }
        }
    }
    # O uvozovkách, které mají z obou stran mezeru, jsme nemohli říct nic.
    # Nyní tedy zkusíme vzít v úvahu pořadí uvozovky (liché vs. sudé), i když je to riskantní (uvozovka může ukončovat něco, co začalo jinou větou,
    # nebo může některá uvozovka kvůli chybě chybět zcela).
    if(!$vse_rozhodnuto)
    {
        $vse_rozhodnuto = 1;
        # Pořadí poslední uvozovky.
        my $iq = 0;
        for(my $i = 0; $i<=$#znaky; $i++)
        {
            if($znaky[$i] =~ m/$q/)
            {
                $iq++;
                # Jestliže už jsme uvozovku rozhodli, nedělat nic.
                if(!$rozhodnuto[$i])
                {
                    # Jestliže kolem uvozovky nejsou mezery, nedělat taky nic. Chtělo by to prohlédnout a ověřit, že nejde o dosud neznámé pravidlo.
                    # Výjimka: před uvozovkou je mezera a za ní čárka. Tohle jsem viděl jednou jako koncovou, ale nejsem si jist, jak to bude jinde.
                    # Jinak je lichá uvozovka počáteční a sudá koncová.
                    if($i>0 && $znaky[$i-1] =~ m/\s/ && $i<$#znaky && $znaky[$i+1] =~ m/[\s,]/)
                    {
                        if($iq%2==1)
                        {
                            $pocatecni[$i]++;
                        }
                        else
                        {
                            $koncova[$i]++;
                        }
                    }
                    else
                    {
                        $vse_rozhodnuto = 0;
                    }
                }
            }
        }
    }
    # Zůstaly ve větě nějaké nerozhodnuté uvozovky?
    if(!$vse_rozhodnuto)
    {
        my $vystup;
        for(my $i = 0; $i<=$#znaky; $i++)
        {
            $vystup .= $znaky[$i];
            my $znacka;
            if($pocatecni[$i])
            {
                $znacka .= 'P'.$pocatecni[$i];
            }
            if($koncova[$i])
            {
                $znacka .= 'K'.$koncova[$i];
            }
            if($zadna[$i])
            {
                $znacka .= 'Z'.$zadna[$i];
            }
            if($znaky[$i] =~ m/$q/ && !$rozhodnuto[$i])
            {
                $znacka .= '!';
            }
            if($znacka ne '')
            {
                $vystup .= "[$znacka]";
            }
        }
        # Jestliže stále existují případy, které neumíme rozhodnout, ohlásit to, abychom mohli rozšířit pravidla.
        print STDERR ("$vystup\n");
        # die;
    }
    # Jestliže jsme se dostali až sem, věta už neobsahuje žádné neorientované uvozovky.
    # Vrátit upravenou větu s orientovanými uvozovkami.
    # Jazykově závislé: zatím používáme pouze španělské uvozovky z dvojitých skobiček.
    my $vystup;
    for(my $i = 0; $i<=$#znaky; $i++)
    {
        if($zadna[$i]>$pocatecni[$i] && $zadna[$i]>$koncova[$i])
        {
            $vystup .= $znaky[$i];
        }
        elsif($pocatecni[$i]>$koncova[$i])
        {
            $vystup .= $q0;
        }
        elsif($koncova[$i]>$pocatecni[$i])
        {
            $vystup .= $q1;
        }
        else
        {
            if($znaky[$i] eq '"')
            {
                ###!!!die("$veta\n$vystup\n");
            }
            $vystup .= $znaky[$i];
        }
    }
    return $vystup;
}
