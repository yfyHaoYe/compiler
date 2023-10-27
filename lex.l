%{
    #include "syntax.tab.h"
    #include "lex_interface.h"
    #include <stdbool.h>
    #include <stdarg.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    void lexError(const char *s);
    bool error = false;
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
int|float|char {yylval.string = strdup(yytext);return TYPE;}
\n {return EOL;}
[\t\r ]+ {}
0(x|X){hex_digit}+ {yylval.string = strdup(yytext); return HEXINT;}
{digit}+ {yylval.string = strdup(yytext); return DECINT;}
'[^']' {yylval.string = strdup(yytext); return PCHAR;}
'\\x{hex_digit}+' {yylval.string = strdup(yytext); return HEXCHAR;}
{letter_}({letter_}|{digit})* {yylval.string = strdup(yytext); return ID;} 
{digit}+{DOT}{digit}+ {yylval.string = strdup(yytext); return FLOAT;}
%%
