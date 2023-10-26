%{
    #include "syntax.tab.h"
    #include "lex_interface.h"
    #include <stdbool.h>
    #include <stdarg.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    void lexError(const char *s);
    int line = 1;
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
int|float|char {return TYPE;}
\n {line++;}
[\t\r ]+ {}
0(x|X){hex_digit}+ {return HEXINT;}
{digit}+ {return DECINT;}
'[^']' {return PCHAR;}
'\\x{hex_digit}+' {return HEXCHAR;}
{letter_}({letter_}|{digit})* {return ID;} 
{digit}+{DOT}{digit}+ {return FLOAT;}
. {lexError("Error Type A at Line:");}
%%
void lexError(const char *s){
    printf("Error type A at Line: %d\n", line);
    error = true;
}
