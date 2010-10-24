#!/usr/bin/perl
# Converts 


use Parse::Lex;
@token = (
  qw(
     LEFTP    [\(]
     RIGHTP   [\),?]
     FLOAT  -?[0-9]*\.[0-9]*|[1-9][0-9]*
     NEWLINE  \n
     
    ),
  # qw(ARCLABEL),   [qw(' [^\\']+ ')],
  qw(ARCLABEL),   [qw(' (?:[^']+)* ')],
  qw(STRING),     [qw(" (?:[^"]+|"")* ")],
  qw(ERROR  .*), sub {
    die qq!can\'t analyze: "$_[1]"!;
  }
 );

Parse::Lex->trace;  # Class method
$lexer = Parse::Lex->new(@token);
$lexer->from(\*DATA);
print "Tokenization of DATA:\n";

TOKEN:while (1) {
  $token = $lexer->next;
  if (not $lexer->eoi) {
    print "Line $.\t";
    print "Type: ", $token->name, "\t";
    print "Content:->", $token->text, "<-\n";
  } else {
    last TOKEN;
  }
}

__END__
((("Prague",0.5,1),("New",0.5,3),),(("Stock",1,1),),(("Market",1,4),),(("York",1,1),),(("Stock",1,1),),(("Exchange",1,1),),(("falls",0.5,1),("drops",0.5,1),),((".",1,1),),)
((('Prague',0.5,1),('New',0.5,3),),(('Stock',1,1),),(('Market',1,4),),(('York',1,1),),(('Stock',1,1),),(('Exchange',1,1),),(('falls',0.5,1),('drops',0.5,1),),(('.',1,1),),)
