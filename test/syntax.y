%{
    #include "lex.yy.c"
    void yyerror(const char*);
%}
%token INT ADD SUB MUL DIV LP RP

%%
Calc: /* to allow empty input */
    | Exp { printf("= %d\n", $1); }
    ;
Exp: INT
    | LP Exp RP { $$ = $2; }
    | Exp ADD Exp { 
        $$ = $1 + $3; 
        if ($3 > 10) {
            return;
        }
        printf("the second int < 10\n");
    }
    | Exp SUB Exp { $$ = $1 - $3; }
    | Exp MUL Exp { $$ = $1 * $3; }
    | Exp DIV Exp { 
        if($3 != 0) 
            $$ = $1 / $3; 
        else 
            return;
        printf("dividing\n"); 
    }
    ;
%%
void yyerror(const char *s) {
    fprintf(stderr, "%s\n", s);
}
int main() {
    yyparse();
}
