%{
    #include "tree_node.h"
    #include "lex.yy.c"
    #include <stdio.h>
    #include <string.h>
    #include "lex_interface.h"
    #include <stdbool.h>
    int yydebug = 1;
    char* convertToDec(char*);
    int yyerror(char *);
    FILE* output_file;
    TreeNode* createNode(char* type, char* value, int line, int numChildren, ...) {
        TreeNode* newNode = (TreeNode*)malloc(sizeof(TreeNode));
        newNode->type = strdup(type);
        newNode->value = strdup(value);
        newNode->line = line;
        newNode->numChildren = numChildren;
        newNode->empty = false;
        //printf("%s %s %d\n", type, value, line);
        if (numChildren > 0) {
            va_list args;
            va_start(args, numChildren);
            newNode->children = (TreeNode**)malloc(numChildren * (sizeof(TreeNode*) + 2));
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
        node->empty = true;
        return node;
    }

    void printParseTree(TreeNode* node, int level);

    char num[50];

%}
%union {
    TreeNode* node;
    char* string;
}
%type<string> INT CHAR
%token<string> TYPE ID FLOAT DECINT HEXINT PCHAR HEXCHAR
%token LP RP LB RB LC RC SEMI COMMA ASSIGN STRUCT RETURN IF ELSE WHILE AND OR NOT LT LE GT GE NE EQ PLUS MINUS MUL DIV DOT EOL
%type<node> Program ExtDefList ExtDef ExtDecList Specifier StructSpecifier VarDec FunDec VarList ParamDec CompSt StmtList Stmt DefList Def DecList Dec Exp Args
%%
Program : ExtDefList {
    $$ = createNode("Program", "", line, 1, $1);
    output_file = fopen("output.out", "w");
    if (output_file == NULL) {
        perror("Unable to open output file");
        exit(1);
    }
    printParseTree($$, 0);
    fclose(output_file); 
}
;
ExtDefList : ExtDef ExtDefList {
    $$ = createNode("ExtDefList", "", line, 2, $1, $2);
}
    | {
    $$ = createNode("ExtDefList", "", line, 0);
    $$->empty = true;
}
;
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
    $$ = createNode("ExtDecList", "", line, 3, $1, createNode("COMMA", "", 0, 0), $3);
}
;
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
;
/* declarator */
VarDec : ID {
    $$ = createNode("VarDec", "", line, 1, createNode("ID", $1, 0, 0));
}
| VarDec LB INT RB {
    $$ = createNode("VarDec", "", line, 4, $1, createNode("LB", "", 0, 0), createNode("INT", $3, 0, 0), createNode("RB", "", 0, 0));
}
FunDec : ID LP VarList RP {
    $$ = createNode("FunDec", "", line, 4, createNode("ID", $1, 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0));
}
| ID LP RP {
    $$ = createNode("FunDec", "", line, 3, createNode("ID", $1, 0, 0), createNode("LP", "", 0, 0), createNode("RP", "", 0, 0));
}
;
VarList : ParamDec COMMA VarList {
    $$ = createNode("VarList", "", line, 3, $1, createNode("COMMA", "", 0, 0), $3);
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
;
StmtList : Stmt StmtList {
    $$ = createNode("StmtList", "", line, 2, $1, $2);
}
|  {
    $$ = createNode("StmtList", "", line, 0);
    $$->empty = true;
}
;
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
    $$ = createNode("Stmt", "", line, 5, createNode("IF", "", 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0), $5);
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", line, 7, createNode("IF", "", 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0), $5, createNode("ELSE", "", 0, 0), $5);
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", line, 5, createNode("WHILE", "", 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0), $5);
}
;
/* local definition */
DefList : Def DefList {
    $$ = createNode("DefList", "", line, 2, $1, $2);
}
|  {
    $$ = createNode("DefList", "", line, 0);
    $$->empty = true;
}
;
Def : Specifier DecList SEMI {
    $$ = createNode("Def", "", line, 3, $1, $2, createNode("SEMI", "", 0, 0));
}
;
DecList : Dec {
    $$ = createNode("DecList", "", line, 1, $1);
}
| Dec COMMA DecList {
    $$ = createNode("DecList", "", line, 3, $1, createNode("COMMA", "", 0, 0), $3);
}
;
Dec : VarDec {
    $$ = createNode("Dec", "", line, 1, $1);
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", line, 3, $1, createNode("ASSIGN", "", 0, 0), $3);
}
;
/* Expression */
Exp : Exp ASSIGN Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("ASSIGN", "", 0, 0), $3);
}
| Exp AND Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("AND", "", 0, 0), $3);
}
| Exp OR Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("OR", "", 0, 0), $3);
}
| Exp LT Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("LT", "", 0, 0), $3);
}
| Exp LE Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("LE", "", 0, 0), $3);
}
| Exp GT Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("GT", "", 0, 0), $3);
}
| Exp GE Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("GE", "", 0, 0), $3);
}
| Exp NE Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("NE", "", 0, 0),$3);
}
| Exp EQ Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("EQ", "", 0, 0), $3);
}
| Exp PLUS Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("PLUS", "", 0, 0), $3);
}
| Exp MINUS Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("MINUS", "", 0, 0),$3);
}
| Exp MUL Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("MUL", "", 0, 0), $3);
}
| Exp DIV Exp {
    $$ = createNode("Exp", "", line, 3, $1, createNode("DIV", "", 0, 0), $3);
}
| LP Exp RP {
    $$ = createNode("Exp", "", line, 3, createNode("LP", "", 0, 0), $2, createNode("RP", "", 0, 0));
}
| MINUS Exp {
    $$ = createNode("Exp", "", line, 2, createNode("MINUS", "", 0, 0), $2);
}
| NOT Exp {
    $$ = createNode("Exp", "", line, 2, createNode("NOT", "", 0, 0), $2);
}

| ID LP RP {
    $$ = createNode("Exp", "", line, 3, createNode("ID", $1, 0, 0), createNode("LP", "", 0, 0), createNode("RP", "", 0, 0));
}
| Exp LB Exp RB {
    $$ = createNode("Exp", "", line, 4, $1, createNode("LB", "", 0, 0), $3, createNode("RB", "", 0, 0));
}
| Exp DOT ID {
    $$ = createNode("Exp", "", line, 3, $1, createNode("DOT", "", 0, 0), createNode("ID", $3, 0, 0));
}
| ID {
    $$ = createNode("Exp", "", line, 1, createNode("ID", $1, 0, 0));
}
| INT {
    $$ = createNode("Exp", "", line, 1, createNode("INT", $1, 0, 0));
}
| FLOAT {
    $$ = createNode("Exp", "", 1, line, createNode("FLOAT", $1, 0, 0));
}
| CHAR {
    $$ = createNode("Exp", "", 1, line, createNode("CHAR", $1, 0, 0));
}
| ID LP Args RP {
    $$ = createNode("Exp", "", line, 4, createNode("ID", $1, 0, 0), createNode("LP", "", 0, 0), $3, createNode("RP", "", 0, 0));
}
|Args {
    $$ = createNode("Exp", "", 0, 1, $1);
}
;
Args : Exp COMMA Args {
    $$ = createNode("Args", "", line, 3, $1, createNode("COMMA", "", 0, 0), $3);
}
| Exp {
    $$ = createNode("Args", "", line, 1, $1);
}
;
INT: DECINT{$$ = strdup($1);} 
| HEXINT {$$ = strdup(convertToDec($1));}
;
CHAR: PCHAR {$$ = strdup($1);}
| HEXCHAR {$$ = strdup($1);}
;
%%


char* convertToDec(char* hexStr) {
    int dec = 0;
    int len = strlen(hexStr);
    for (int i = 2; i < len; i++) {
        if (hexStr[i] >= '0' && hexStr[i] <= '9') {
            dec = dec * 16 + hexStr[i] - '0';
        } else if (hexStr[i] >= 'a' && hexStr[i] <= 'f') {
            dec = dec * 16 + hexStr[i] - 'a' + 10;
        } else if (hexStr[i] >= 'A' && hexStr[i] <= 'F') {
            dec = dec * 16 + hexStr[i] - 'A' + 10;
        }
    }
    sprintf(num, "%d", dec);
    return num;
}

void printParseTree(TreeNode* node, int level) {
    if(node == NULL) return;
    if(!node->empty){
        for (int i = 0; i < level; i++) {
            //fprintf(output_file, "  ");
            printf("  ");
        }
        if(node->line == 0){
            if(strlen(node->value) == 0){
                //fprintf(output_file, "%s\n", node->type);
                printf("%s\n", node->type);
            }else{
                //fprintf(output_file, "%s: %s\n", node->type, node->value);
                printf("%s: %s\n", node->type, node->value);
            }
        }
        //else fprintf(output_file, "%s:%d\n", node->type, node->line);
        else printf("%s (%d)\n", node->type, node->line);
    }

    for (int i = 0; i < node->numChildren; i++) {
        printParseTree(node->children[i], level + 1);
    }
}

int yyerror(char *s) {
    fprintf(stderr, "%s%d", s, line);
    error = true;
    return 0;
}
int main() {
    yyparse();
}
/* int main(int argc, char **argv){
    char *file_path;
    if(argc < 2){
        fprintf(stderr, "Usage: %s <file_path>\n", argv[0]);
        return EXIT_FAIL;
    } else if(argc == 2){
        file_path = argv[1];
        if(!(yyin = fopen(file_path, "r"))){
            perror(argv[1]);
            return EXIT_FAIL;
        }
        yyparse();
        return EXIT_OK;
    } else{
        fputs("Too many arguments! Expected: 2.\n", stderr);
        return EXIT_FAIL;
    }
} */
