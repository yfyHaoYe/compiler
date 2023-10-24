%{
    #include "lex.yy.c"
    int errorOccur = 0;
    int convertToDec(int);
    int yyerror(const char *);
%}
%union {
    int integer_val;
    float float_val;
    char* string_val;
}
%token <integer_val> DECINT HEXINT PCHAR HEXCHAR TYPE STRUCT IF ELSE WHILE RETURN
%token <float_val> FLOAT
%token <string_val> ID
%token DOT SEMI COMMA ASSIGN LT LE GT GE NE EQ PLUS MINUS MUL DIV AND OR NOT LP RP LB RB LC RC 
%%
Program : ExtDefList {if(errorOccur) printf("Program(%d)\n", line);}
    |error {yyerror("Type B Error at Line:");}
ExtDefList : ExtDef ExtDefList {printf("ExtDefList(%d)\n", line);}
    |
ExtDef : Specifier ExtDecList SEMI {printf("ExtDef(%d)\n", line);}
    | Specifier SEMI
    | Specifier FunDec CompSt
ExtDecList : VarDec {printf("ExtDecList(%d)\n", line);}
    | VarDec COMMA ExtDecList
    ;
/* specifier */
Specifier :  TYPE {printf("Specifier(%d)\n", line);}
    | StructSpecifier
StructSpecifier : STRUCT ID LC DefList RC {printf("StructSpecifier(%d)\n", line);}
    | STRUCT ID
    ;
/* declarator */
VarDec : ID {printf("VarDec(%d)\n", line);}
    | VarDec LB DECINT RB
    | VarDec LB HEXINT RB
FunDec : ID LP VarList RP {printf("FunDec(%d)\n", line);}
    | ID LP RP
VarList : ParamDec COMMA VarList {printf("VarList(%d)\n", line);}
    | ParamDec
ParamDec : Specifier VarDec {printf("ParamDec(%d)\n", line);}
    ;
/* statement */
CompSt : LC DefList StmtList RC {printf("CompSt(%d)\n", line);}
StmtList : Stmt StmtList {printf("StmtList(%d)\n", line);}
    |
Stmt : Exp SEMI {printf("ExpStmt(%d)\n", line);}
    | CompSt
    | RETURN Exp SEMI
    | IF LP Exp RP Stmt ElseStmt
    | WHILE LP Exp RP Stmt
ElseStmt : ELSE Stmt
    |
    ;

/* local definition */
DefList : Def DefList {printf("DefList(%d)\n", line);}
    |
Def : Specifier DecList SEMI {printf("Def(%d)\n", line);}
    ;
DecList : Dec {printf("DecList(%d)\n", line);}
    | Dec COMMA DecList
Dec : VarDec {printf("Dec(%d)\n", line);}
    | VarDec ASSIGN Exp
    ;
/* Expression */
Exp : Exp ASSIGN Exp{printf("ASSIGN\n");}
    | Exp AND Exp {printf("AND\n");}
    | Exp OR Exp {printf("OR\n");}
    | Exp LT Exp  {printf("LT\n");}
    | Exp LE Exp {printf("LE\n");}
    | Exp GT Exp {printf("GT\n");}
    | Exp GE Exp {printf("GE\n");}
    | Exp NE Exp {printf("NE\n");}
    | Exp EQ Exp {printf("EQ\n");}
    | Exp PLUS Exp {printf("PLUS\n");}
    | Exp MINUS Exp {printf("MINUS\n");}
    | Exp MUL Exp {printf("MUL\n");}
    | Exp DIV Exp {printf("DIV\n");}
    | LP Exp RP 
    | MINUS Exp
    | NOT Exp
    | ID LP Args RP
    | ID LP RP
    | Exp LB Exp RB
    | Exp DOT ID
    | ID {printf("ID:%s\n", $1);}
    | DECINT {printf("INT:%d\n", $1);}
    | HEXINT {printf("INT:%d\n", convertToDec($1));}
    | FLOAT {printf("FLOAT:%f\n", $1);}
    | PCHAR {printf("CHAR:%c\n", $1);}
    | HEXCHAR {printf("CHAR:%c\n", $1);}
    ;
Args : Exp COMMA Args
    | Exp
    ;
%%
int convertToDec(int hex) {
    int dec = 0;
    int base = 1;
    while (hex > 0) {
        dec += (hex % 10) * base;
        hex /= 10;
        base *= 16;
    }
    return dec;
}

int yyerror(const char *s) {
    fprintf(stderr, "%s%d", s, line);
    errorOccur = 1;
    return 0;
}
int main() {
    yyparse();
}
