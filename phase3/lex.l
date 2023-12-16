%{
    #include "syntax.tab.h"
    #include "script/my_print.c"
    #include <stdbool.h>
    #include <stdarg.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    int line = 1;
    bool error = false;
    
    // phase2
    void push();
    void pop();
%}
%x COMMENT
letter [a-zA-Z]
letter_ {letter}|_
digit [0-9]
digitno0 [1-9]
hex_digit [0-9a-fA-F]
char [^\n\t]
TYPE  ["int"|"float"|"char"]
DOT "\."
SIN_QUOTE "\'"
%%
"//" {
    char c; 
    while(true){
        c=input();
        if (c== '\n'| c=='\0'){
            break;
        }
    }; 
    line++;
}
"/*" { BEGIN(COMMENT); }
<COMMENT>{
    "*/" { BEGIN(INITIAL); }
    \n {line++;}
    . {}
} 
struct {yylval.str_line.line = line;return STRUCT;}
if {yylval.str_line.line = line;return IF;}
else {yylval.str_line.line = line;return ELSE;}
while {yylval.str_line.line = line;return WHILE;}
return {yylval.str_line.line = line;return RETURN;}
";" {yylval.str_line.line = line;return SEMI;}
"," {yylval.str_line.line = line;return COMMA;}
"=" {yylval.str_line.line = line;return ASSIGN;}
"<" {yylval.str_line.line = line;return LT;}
"<=" {yylval.str_line.line = line;return LE;}
">" {yylval.str_line.line = line;return GT;}
">=" {yylval.str_line.line = line;return GE;}
"!=" {yylval.str_line.line = line;return NE;}
"==" {yylval.str_line.line = line;return EQ;}
"+" {yylval.str_line.line = line;return PLUS;}
"-" {yylval.str_line.line = line;return MINUS;}
"*" {yylval.str_line.line = line;return MUL;}
"/" {yylval.str_line.line = line;return DIV;}
"&&" {yylval.str_line.line = line;return AND;}
"||" {yylval.str_line.line = line;return OR;}
"!" {yylval.str_line.line = line;return NOT;}
"(" {yylval.str_line.line = line;return LP;}
")" {yylval.str_line.line = line;return RP;}
"[" {yylval.str_line.line = line;return LB;}
"]" {yylval.str_line.line = line;return RB;}
"{" {push();yylval.str_line.line = line;return LC;}
"}" {pop();yylval.str_line.line = line;return RC;}
{DOT} {yylval.str_line.line = line;return DOT;}
int|float|char|string {yylval.str_line.string = strdup(yytext);yylval.str_line.line = line; return TYPE;}
\n {line++;}
[\t\r ]+ {}
0(x|X){hex_digit}+ {
    if (yyleng < 35) {
        yylval.str_line.string = strdup(yytext); 
        yylval.str_line.line = line;
        return HEXINT;
    } else {
        printf("Error type A at Line %d: Integer length exceed limit 32 \'%s\'\n", line, yytext); 
        error = true;
        return STR;
    }
}
(({digitno0}{digit}*)|0) {
    if (yyleng < 32){
        yylval.str_line.string = strdup(yytext);
        yylval.str_line.line = line;
        return DECINT;
    } else {
        printf("Error type A at Line %d: Integer length exceed limit 32 \'%s\'\n", line, yytext);
        error = true;
        return STR;
    }
}
'[^']{1}' {yylval.str_line.string = strdup(yytext);yylval.str_line.line = line; return PCHAR;}
'\\(x|X){hex_digit}{1,2}\' {yylval.str_line.string = strdup(yytext);yylval.str_line.line = line; return HEXCHAR;} 
' { printf("Error type A at Line %d: Missing single quotation '\n", line); }
\" { printf("Error type A at Line %d: Missing double quotation \" \n", line); }
(({digitno0}{digit}*)|0){DOT}{digit}+ {yylval.str_line.string = strdup(yytext);yylval.str_line.line = line; return FLOAT;}
{letter_}({letter_}|{digit})* {yylval.str_line.string = strdup(yytext);yylval.str_line.line = line; return ID;}
({letter_}|{digit})+{letter_}+ {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return ID;}
\"[^\"]*\" {
    if(yytext[yyleng-2] == '\\') {
        yyless(yyleng-1);
        yymore();
    } else {
        yylval.str_line.string = strdup(yytext);
        yylval.str_line.line = line;
        return STR;
    }
}
0(x|X)({letter}|{digit})+ {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return STR;}
"&"|"|" {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true;return AND;}
[^\'\"\\] {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return STR;}
'\\x{hex_digit}{3,}' {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return HEXCHAR;}
'\\x[^{hex_digit}]+' {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return STR;}
'[^']{2,}' {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return PCHAR;}
{digit}+{DOT}{digit}+ {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return FLOAT;}
{digit}+ {printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return DECINT;}
. { printf("Error type A at Line %d: Unknown characters \'%s\'\n", line, yytext); error = true; return STR; }
%%
