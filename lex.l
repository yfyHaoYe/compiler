%{
    #define EXIT_OK 0
    #define EXIT_FAIL 1
    #include "syntax.tab.h"
    #include "stdlib.h"
%}
letter [a-zA-Z]
letter_ {letter}|_
digit [0-9]
hex_digit [0-9a-fA-F]
char [^\n\t]
CharHex "\\x"
hex ["Ox"|"OX"]
TYPE  ["int"|"float"|"char"]
DOT "\."
SIN_QUOTE "\'"

%%
struct {return STRUCT;}
if {return IF;}
else {return ELSE;}
while {return WHILE;}
return {return RETURN;}
";" {return SEMI;}
"," {return COMMA;}
"=" {return ASSIGN;}
"<" {return LT;}
"<=" {return LE;}
">" {return GT;}
">=" {return GE;}
"!=" {return NE;}
"==" {return EQ;}
"+" {return PLUS;}
"-" {return MINUS;}
"*" {return MUL;}
"/" {return DIV;}
"&&" {return AND;}
"||" {return OR;}
"!" {return NOT;}
"(" {return LP;}
")" {return RP;}
"[" {return LB;}
"]" {return RB;}
"{" {return LC;}
"}" {return RC;}
int|float|char {return TYPE;}
\n {}
[\t\r ]+ {}
0(x|X){hex_digit}+ {return HEXINT;}
{digit}+ {return DECINT;}
'[^']' {return PCHAR;}
'\\x{hex_digit}+' {return HEXCHAR;}
{letter_}({letter_}|{digit})* {return ID;} 
{digit}+{DOT}{digit}+ {return FLOAT;}

