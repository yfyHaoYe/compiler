%{
    #include "lex.yy.c"
    int errorOccur = 0;
    int convertToDec(int);
    int yyerror(const char *);
    typedef struct TreeNode {
        char* type;
        char* value;
        int line;
        struct TreeNode* children;
        int numChildren;
    } TreeNode;

    TreeNode* createNode(const char* type, const char* value, int line, int numChildren, ...) {
        TreeNode* newNode = (TreeNode*)malloc(sizeof(TreeNode));
        newNode->type = strdup(type);
        newNode->value = strdup(value);
        newNode->line = line;
        newNode->numChildren = numChildren;
        if (numChildren > 0) {
            va_list args;
            va_start(args, numChildren);
            newNode->children = (TreeNode*)malloc(numChildren * sizeof(TreeNode));
            for (int i = 0; i < numChildren; i++) {
                newNode->children[i] = va_arg(args, TreeNode*);
            }
            va_end(args);
        } else {
            newNode->children = NULL;
        }
        return newNode;
    }

    TreeNode* convertNull(TreeNode* node) {
        node.type = "";
        return node;
    }

%}
%union {
    TreeNode* node;
    int integer;
    float float;
    char* string;
}
%token <float> FLOATNUM
%token <string> PCHAR HEXCHAR
%token <integer> DECINT HEXINT
%type <string> INT FLOAT CHAR
%token <string> TYPE ID
%token <string> LP RP LB RB LC RC SEMI COMMA ASSIGN
%token <string> AND OR NOT
%type <node> Program ExtDefList ExtDef ExtDecList Specifier StructSpecifier VarDec FunDec VarList ParamDec CompSt StmtList DefList Def DecList Dec Args
%%
Program : ExtDefList {
    $$ = createNode("Program", "", line, 1, $1);
}
ExtDefList : ExtDef ExtDefList {
    $$ = createNode("ExtDefList", "", line, 2, $1, convertNull($2));
}
    | {
    $$ = createNode("ExtDefList", "", line, 0);
}
ExtDef : Specifier ExtDecList SEMI {
    $$ = createNode("ExtDef", "", line, 3, $1, $2, createNode("SEMI", "", 0, 0));
}
| Specifier SEMI {
    $$ = createNode("ExtDef", "", line, 2, $1, createNode("SEMI", "", 0, 0));
}
| Specifier FunDec CompSt {
    $$ = createNode("ExtDef", "", line, 3, $1, $2, $3);
}
ExtDecList : VarDec {
    $$ = createNode("ExtDecList", "", line, 1, $1);
}
| VarDec COMMA ExtDecList {
    $$ = createNode("ExtDecList", "", line, 3, $1, createNode("COMMA", "", 0, 0), convertNull($3));
}
/* specifier */
Specifier : TYPE {
    $$ = createNode("Specifier", "", line, 1, createNode("TYPE", $1, 0, 0));
}
| StructSpecifier {
    $$ = createNode("Specifier", "", line, 1, $1);
}
StructSpecifier : STRUCT ID LC DefList RC {
    $$ = createNode("StructSpecifier", "", line, 5, createNode("STRUCT", "", 0, 0), createNode("ID", $2, 0, 0), createNode("LC", "", 0, 0), $4, createNode("RC", "", 0, 0));
}
| STRUCT ID {
    $$ = createNode("StructSpecifier", "", line, 2, createNode("STRUCT", "", 0, 0), createNode("ID", $2, 0, 0));
}
/* declarator */
VarDec : ID {
    $$ = createNode("VarDec", "", line, 1, createNode("ID", $1, 0, 0));
}
| VarDec LB INT RB {
    $$ = createNode("VarDec", "", line, 4, convertNull($1), createNode("LB", "", 0, 0), createNode("INT", $3, 0, 0), createNode("RB", "", 0, 0));
}
FunDec : ID LP VarList RP {
    $$ = createNode("FunDec", "", line, 4, createNode("ID", $2, 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0));
}
| ID LP RP {
    $$ = createNode("FunDec", "", line, 3, createNode("ID", $1, 0, 0), createNode("LP", "", 0, 0), createNode("RP", "", 0, 0));
}

VarList : ParamDec COMMA VarList {
    $$ = createNode("VarList", "", line, 3, $1, createNode("COMMA", "", 0, 0), convertNull($3));
}
| ParamDec {
    $$ = createNode("VarList", "", line, 1, $1);
}
ParamDec : Specifier VarDec {
    $$ = createNode("ParamDec", "", line, 2, $1, $2);
}
    ;
/* statement */
CompSt : LC DefList StmtList RC {
    $$ = createNode("CompSt", "", line, 4, createNode("LC", "", 0, 0), $2, $3, createNode("RC", "", 0, 0));
}

StmtList : Stmt StmtList {
    $$ = createNode("StmtList", "", line, 2, $1, convertNull($2));
}
|  {
    $$ = createNode("StmtList", "", line, 0);
}

Stmt : Exp SEMI {
    $$ = createNode("Stmt", "", line, 2, $1, createNode("SEMI", "", 0, 0));
}
| CompSt {
    $$ = createNode("Stmt", "", line, 1, $1);
}
| RETURN Exp SEMI {
    $$ = createNode("Stmt", "", line, 3, createNode("RETURN", "", 0, 0), $2, createNode("SEMI", "", 0, 0));
}
| IF LP Exp RP Stmt {
    $$ = createNode("Stmt", "", 5, createNode("IF", "", 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0), convertNull($5));
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", 7, createNode("IF", "", 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0), convertNull($5), createNode("ELSE", "", 0, 0), convertNull($7));
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", 5, createNode("WHILE", "", 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0), convertNull($5));
}

/* local definition */
DefList : Def DefList {
    $$ = createNode("DefList", "", line, 2, $1, convertNull($2));
}
|  {
    $$ = createNode("DefList", "", line, 0);
}

Def : Specifier DecList SEMI {
    $$ = createNode("Def", "", line, 3, $1, $2, createNode("SEMI", "", 0, 0));
}

DecList : Dec {
    $$ = createNode("DecList", "", line, 1, $1);
}
| Dec COMMA DecList {
    $$ = createNode("DecList", "", line, 3, $1, createNode("COMMA", "", 0, 0), convertNull($3));
}

Dec : VarDec {
    $$ = createNode("Dec", "", line, 1, $1);
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", line, 3, $1, createNode("ASSIGN", "", 0, 0), $3);
}
/* Expression */
Exp : Exp ASSIGN Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("ASSIGN", "", 0, 0), convertNull($3));
}
| Exp AND Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("AND", "", 0, 0), convertNull($3));
}
| Exp OR Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("OR", "", 0, 0), convertNull($3));
}
| Exp LT Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("LT", "", 0, 0), convertNull($3));
}
| Exp LE Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("LE", "", 0, 0), convertNull($3));
}
| Exp GT Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("GT", "", 0, 0), convertNull($3));
}
| Exp GE Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("GE", "", 0, 0), convertNull($3));
}
| Exp NE Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("NE", "", 0, 0), convertNull($3));
}
| Exp EQ Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("EQ", "", 0, 0), convertNull($3));
}
| Exp PLUS Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("PLUS", "", 0, 0), convertNull($3));
}
| Exp MINUS Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("MINUS", "", 0, 0), convertNull($3));
}
| Exp MUL Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("MUL", "", 0, 0), convertNull($3));
}
| Exp DIV Exp {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("DIV", "", 0, 0), convertNull($3));
}
| LP Exp RP {
    $$ = createNode("Exp", "", line, 3, createNode("LP", "", 0, 0), convertNull($2), createNode("RP", "", 0, 0));
}
| MINUS Exp {
    $$ = createNode("Exp", "", line, 2, createNode("MINUS", "", 0, 0), convertNull($2));
}
| NOT Exp {
    $$ = createNode("Exp", "", line, 2, createNode("NOT", "", 0, 0), convertNull($2));
}
| ID LP Args RP {
    $$ = createNode("Exp", "", line, 4, createNode("ID", $1, 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0));
}
| ID LP RP {
    $$ = createNode("Exp", "", line, 3, createNode("ID", $1, 0, 0), createNode("LP", "", 0, 0), createNode("RP", "", 0, 0));
}
| Exp LB Exp RB {
    $$ = createNode("Exp", "", line, 4, convertNull($1), createNode("LB", "", 0, 0), convertNull($3), createNode("RB", "", 0, 0));
}
| Exp DOT ID {
    $$ = createNode("Exp", "", line, 3, convertNull($1), createNode("DOT", "", 0, 0), createNode("ID", $3, 0, 0));
}
| ID {
    $$ = createNode("Exp", "", 1, createNode("ID", $1, 0, 0));
}
| INT {
    $$ = createNode("Exp", "", 1, createNode("INT", $1, 0, 0));
}
| FLOAT {
    $$ = createNode("Exp", "", 1, createNode("FLOAT", $1, 0, 0));
}
| CHAR {
    $$ = createNode("Exp", "", 1, createNode("CHAR", $1, 0, 0));
}
| Args {
    $$ = createNode("Exp", "", 0, 1, $1);
}
;
Args : Exp COMMA Args {
    $$ = createNode("Args", "", line, 3, $1, createNode("COMMA", "", 0, 0), convertNull($3));
}
| Exp {
    $$ = createNode("Args", "", line, 1, $1);
}
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
