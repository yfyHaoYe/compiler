%{
    #include "syntax.tab.h"
    #include "lex_interface.h"
    #include <stdbool.h>
    #include <stdarg.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    int line = 1;
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
"//" { char c; while((c=input()) != '\n'); }
"/*"[^*/]"*/" {  }
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
{DOT} {return DOT;}
int|float|char|string {yylval.string = strdup(yytext);return TYPE;}
\n {line++;}
[\t\r ]+ {}
\"[^\"|\\"]*\" {yylval.string = strdup(yytext);return STR;}
0(x|X){hex_digit}+ {yylval.string = strdup(yytext); return HEXINT;}
{digit}+ {yylval.string = strdup(yytext); return DECINT;}
'[^']' {yylval.string = strdup(yytext); return PCHAR;}
'\\x{hex_digit}+' {yylval.string = strdup(yytext); return HEXCHAR;}
{letter_}({letter_}|{digit})* {yylval.string = strdup(yytext); return ID;} 
{digit}+{DOT}{digit}+ {yylval.string = strdup(yytext); return FLOAT;}
. { printf("Error type A at Line %d: Unknown characters \'%s\'\n", yylineno, yytext); }
%%
