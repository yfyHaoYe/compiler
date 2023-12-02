%{
    #include "tree_node.h"
    #include "type_table.h"
    #include "linked_list.h"
    #include <stdlib.h>
    #include "lex.yy.c"
    #include <stdio.h>
    #include <string.h>
    #include "lex_interface.h"
    #include <stdbool.h>
    char* convertToDec(char*);
    int typeError(const char *msg, int type, int line);
    int yyerror(const char *);
    TypeTable* typeTable;
    void findNode(TreeNode* node, ListNode** list, char* type);
    void printParseTree(TreeNode* node, int level);
    void getOutputPath(const char *input_path, char *output_path, size_t output_path_size);
    TreeNode* createNode(char* type, char* value, int line, int numChildren, ...);
    TreeNode* convertNull(TreeNode* node);
    char num[50];
    void processArray(TreeNode* varDec, Type* type, TreeNode* specifier);
    Type* processStruct(TreeNode* structSpecifier);
    void freeTree(TreeNode* node);
    Type* checkExp(TreeNode* Exp, TypeTable* subTable);
    Type* getIndexType(TreeNode* Exp, TypeTable* subTable);
    void findNodeExcept(TreeNode* node, ListNode** list, char* type, char* except);

%}
%union {
    struct {
        char* string;
        int line;
    } str_line;
    TreeNode* node;
}
%type<str_line> INT CHAR
%token<str_line> TYPE ID FLOATNUM DECINT HEXINT PCHAR HEXCHAR STR
%token<str_line.line> LC RC SEMI COMMA STRUCT RETURN WHILE IF
%type<node> Program ExtDefList ExtDef ExtDecList Specifier StructSpecifier VarDec FunDec VarList ParamDec CompSt StmtList Stmt DefList Def DecList Dec Exp Args ErrorStmt
%nonassoc<node> LOWER
%nonassoc<str_line.line> ELSE
%nonassoc<str_line.line> ASSIGN
%left<str_line.line> OR
%left<str_line.line> AND
%nonassoc<str_line.line> LT LE GT GE NE EQ
%left<str_line.line> PLUS MINUS
%left<str_line.line> MUL DIV
%left<str_line.line> NOT
%left<str_line.line> LP RP LB RB DOT
%%
Program : ExtDefList {
    $$ = createNode("Program", "", $1->line, 1, $1);
    if (output_file == NULL) {
        perror("Unable to open output file");
        exit(1);
    }
    if(!error){
        //printParseTree($$, 0);
        freeTree($$);
    }
}
;
ExtDefList : ExtDef ExtDefList {
    $$ = createNode("ExtDefList", "", $1->line, 2, $1, $2);
}
    | {
    $$ = createNode("ExtDefList", "", 0, 0);
    $$->empty = true;
}
;
ExtDef : Specifier ExtDecList SEMI {
    //静态变量
    $$ = createNode("ExtDef", "", $1->line, 3, $1, $2, createNode("SEMI", "", $3, 0));
    //add primitive type to type table
    TreeNode* cur = $2;
    ListNode** decList = (ListNode**)malloc(sizeof(ListNode*));
    *decList = NULL;
    findNode(cur, decList, "Dec");
    ListNode* curDec = *decList;
    char* name;
    int curLine;
    while(curDec != NULL){
        TreeNode* varDec = curDec->node->children[0];
        Type* type = (Type*)malloc(sizeof(Type));
        if(curDec->node->numChildren == 3){
            type->init = 1;
        }else{
            type->init = 0;
        }
        if(varDec->numChildren == 1){
            //普通变量
            name = varDec->children[0]->value;
            strcpy(type->name, name);
            type->category = PRIMITIVE;
            curLine = varDec->children[0]->line;
            char* typeName = $1->children[0]->value;
            if(strcmp(typeName, "int") == 0){
                type->primitive = INT;
            }else if(strcmp(typeName, "float") == 0){
                type->primitive = FLOAT;
            }else if(strcmp(typeName, "char") == 0){
                type->primitive = CHAR;
            }
        }else{
            //数组
            processArray(varDec, type, $1);
            /* int wrong = insertIntoTypeTable(typeTable, type->name, type);
            if(wrong == 1){
                char errorMsg[50];
                strcpy(errorMsg, "variable \"");
                strcpy(errorMsg + 10, type->name);
                strcpy(errorMsg + 10 + strlen(type->name), "\" is redefined in the same scope");
                typeError(errorMsg, 3, varDec->children[2]->line);
            } */
        }
        int wrong = insertIntoTypeTable(typeTable, name, type);
        if(wrong == 1){
            char errorMsg[50];
            strcpy(errorMsg, "variable \"");
            strcpy(errorMsg + 10, name);
            strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
            typeError(errorMsg, 3, curLine);
        }
        curDec = curDec->next;
    }
    freeList(decList);
}
| Specifier SEMI {
    $$ = createNode("ExtDef", "", $1->line, 2, $1, createNode("SEMI", "", $2, 0));
    //add struct type to type table
    TreeNode* structSpecifier = $1->children[0];
    Type* type = processStruct(structSpecifier);
    char* name = type->name;
    int wrong = insertIntoTypeTable(typeTable, name, type);
    if(wrong == 1){
        char errorMsg[50];
        strcpy(errorMsg, "variable \"");
        strcpy(errorMsg + 10, name);
        strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
        typeError(errorMsg, 3,structSpecifier->children[1]->line);
    }
}
| Specifier FunDec CompSt {
    $$ = createNode("ExtDef", "", $1->line, 3, $1, $2, $3);
    TypeTable* funcVarTable = (TypeTable*)malloc(sizeof(TypeTable));
    //函数定义,函数参数定义FunDec
    TreeNode* funDec = $2;
    ListNode** paramDecList = (ListNode**)malloc(sizeof(ListNode*));
    *paramDecList = NULL;
    findNode(funDec, paramDecList, "ParamDec");
    ListNode* curParamDec = *paramDecList;
    while(curParamDec != NULL){
        TreeNode* specifier = curParamDec->node->children[0];
        char* name = curParamDec->node->children[1]->children[0]->value;
        if(strcmp(specifier->children[0]->type, "TYPE") == 0){
            Type* type = (Type*)malloc(sizeof(Type));
            type->category = PRIMITIVE;
            strcpy(type->name, name);
            char* typeName = specifier->children[0]->value;
            if(strcmp(typeName, "int") == 0){
                type->primitive = INT;
            }else if(strcmp(typeName, "float") == 0){
                type->primitive = FLOAT;
            }else if(strcmp(typeName, "char") == 0){
                type->primitive = CHAR;
            }
            int wrong = insertIntoTypeTable(funcVarTable, name, type);
            if(wrong == 1){
                char errorMsg[50];
                strcpy(errorMsg, "variable \"");
                strcpy(errorMsg + 10, name);
                strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
                typeError(errorMsg, 3, curParamDec->node->children[1]->children[0]->line);
            }
        }else{
            Type* type = getType(typeTable, specifier->children[0]->children[1]->value);
            if(type == NULL) {
                char errorMsg[50];
                strcpy(errorMsg, "variable \"");
                strcpy(errorMsg + 10, name);
                strcpy(errorMsg + 10 + strlen(name), "\" is used without a definition");
                typeError(errorMsg, 1, curParamDec->node->children[1]->children[0]->line);
            }else{
                int wrong = insertIntoTypeTable(funcVarTable, name, type);
                if(wrong == 1){
                    char errorMsg[50];
                    strcpy(errorMsg, "variable \"");
                    strcpy(errorMsg + 10, name);
                    strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
                    typeError(errorMsg, 3, curParamDec->node->children[1]->children[0]->line);
                }
            }
        }
        curParamDec = curParamDec->next;
    }
    //函数内部变量定义CompSt
    TreeNode* compSt = $3;
    ListNode** defList = (ListNode**)malloc(sizeof(ListNode*));
    *defList = NULL;
    findNode(compSt, defList, "Def");
    ListNode* curDef = *defList;
    while(curDef != NULL){
        TreeNode* specifier = curDef->node->children[0];
        ListNode** decList = (ListNode**)malloc(sizeof(ListNode*));
        *decList = NULL;
        findNode(curDef->node->children[1], decList, "Dec");
        ListNode* curDec = *decList;
        while(curDec != NULL){
            TreeNode* varDec = curDec->node->children[0];
            if(varDec->numChildren == 1){
                TreeNode* id = varDec->children[0];
                char* name = id->value;
                Type* type = (Type*)malloc(sizeof(Type));
                if(strcmp(specifier->children[0]->type, "TYPE") == 0){
                    type->category = PRIMITIVE;
                    strcpy(type->name, name);
                    char* typeName = specifier->children[0]->value;
                    if(strcmp(typeName, "int") == 0){
                        type->primitive = INT;
                    }else if(strcmp(typeName, "float") == 0){
                        type->primitive = FLOAT;
                    }else if(strcmp(typeName, "char") == 0){
                        type->primitive = CHAR;
                    }
                }else{
                    type = getType(typeTable, specifier->children[0]->children[1]->value);
                }
                int wrong = insertIntoTypeTable(funcVarTable, name, type);
                if(wrong == 1){
                    char errorMsg[50];
                    strcpy(errorMsg, "variable \"");
                    strcpy(errorMsg + 10, name);
                    strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
                    typeError(errorMsg, 3, id->line);
                }
            }else{
                //数组
                Type* type = (Type*)malloc(sizeof(Type));
                processArray(varDec, type, specifier);
                int wrong = insertIntoTypeTable(typeTable, type->name, type);
                if(wrong == 1){
                    char errorMsg[50];
                    strcpy(errorMsg, "variable \"");
                    strcpy(errorMsg + 10, type->name);
                    strcpy(errorMsg + 10 + strlen(type->name), "\" is redefined in the same scope");
                    typeError(errorMsg, 3, varDec->children[2]->line);
                }
            }
            curDec = curDec->next;
        }
        curDef = curDef->next;
    }
    //检查未定义变量
    curDef = *defList;
    while(curDef != NULL){
        ListNode** decList = (ListNode**)malloc(sizeof(ListNode*));
        *decList = NULL;
        findNode(curDef->node, decList, "Dec");
        ListNode* curDec = *decList;
        while(curDec != NULL){
            if(curDec->node->numChildren == 3){
                TreeNode* exp = curDec->node->children[2];
                ListNode** idList = (ListNode**)malloc(sizeof(ListNode*));
                *idList = NULL;
                if(exp->numChildren == 4 && strcmp(exp->children[2]->type, "Args") == 0){
                    findNode(exp->children[2], idList, "ID");
                }else{
                    findNode(exp, idList, "ID");
                }
                ListNode* curId = *idList;
                while(curId != NULL){
                    char* name = curId->node->value;
                    int len = strlen(name);
                    if(!(isContains(funcVarTable, name) || isContains(typeTable, name))){
                        char errorMsg[50];
                        strcpy(errorMsg, name);
                        strcpy(errorMsg + len, " is used without a definition");
                        typeError(errorMsg, 1, curId->node->line);
                    }
                    curId = curId->next;
                }
            }
            curDec = curDec->next;
        }
        free(decList);
        curDef = curDef->next;
    }
    free(defList);
    ListNode** stmtList = (ListNode**)malloc(sizeof(ListNode*));
    *stmtList = NULL;
    findNode(compSt, stmtList, "Stmt");
    ListNode* curStmt = *stmtList;
    /* while(curStmt != NULL){
        if(curStmt->node->numChildren == 2){
            TreeNode* exp = curStmt->node->children[0];
            ListNode** idList = (ListNode**)malloc(sizeof(ListNode*));
            *idList = NULL;
            findNode(exp, idList, "ID");
            ListNode* curId = *idList;
            while(curId != NULL){
                char* name = curId->node->value;
                int len = strlen(name);
                if(!(isContains(funcVarTable, name) || isContains(typeTable, name))){
                    char errorMsg[50];
                    strcpy(errorMsg, name);
                    strcpy(errorMsg + len, " is used without a definition");
                    typeError(errorMsg, 1, curId->node->line);
                }
                curId = curId->next;
            }
            free(idList);
        }
        curStmt = curStmt->next;
    } */
    //检查运算变量是否合法
    curStmt = *stmtList;
    while(curStmt != NULL){
        if(curStmt->node->numChildren == 2){
            TreeNode* exp = curStmt->node->children[0];
            checkExp(exp, funcVarTable);
        }else if(curStmt->node->numChildren == 3){
            //return
            TreeNode* exp = curStmt->node->children[1];
            checkExp(exp, funcVarTable);
        }
        curStmt = curStmt->next;
    }
    free(stmtList);
}
| Specifier error {
    yyerror(" Missing semicolon ';'");
}
| Specifier ExtDecList error {
    yyerror(" Missing semicolon ';'");
}
;
ExtDecList : VarDec {
    $$ = createNode("ExtDecList", "", $1->line, 1, $1);
}
| VarDec COMMA ExtDecList {
    $$ = createNode("ExtDecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
;
/* specifier */
Specifier : TYPE {
    $$ = createNode("Specifier", "", $1.line, 1, createNode("TYPE", $1.string, $1.line, 0));
}
| StructSpecifier {
    $$ = createNode("Specifier", "", $1->line, 1, $1);
}
;
StructSpecifier : STRUCT ID LC DefList RC {
    $$ = createNode("StructSpecifier", "", $1, 5, createNode("STRUCT", "", $1, 0), createNode("ID", $2.string, $2.line, 0), createNode("LC", "", $3, 0), $4, createNode("RC", "", $5, 0));
}

| STRUCT ID {
    $$ = createNode("StructSpecifier", "", $1, 2, createNode("STRUCT", "", $1, 0), createNode("ID", $2.string, $2.line, 0));
}
;
/* declarator */
VarDec : ID {
    $$ = createNode("VarDec", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
}
| VarDec LB INT RB {
    $$ = createNode("VarDec", "", $1->line, 4, $1, createNode("LB", "", $2, 0), createNode("INT", $3.string, $3.line, 0), createNode("RB", "", $4, 0));
}
| VarDec LB INT error {
    yyerror(" Missing closing square bracket ']'");
}
;
FunDec : ID LP VarList RP {
    $$ = createNode("FunDec", "", $1.line, 4, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0));
}
| ID LP RP {
    $$ = createNode("FunDec", "", $1.line, 3, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), createNode("RP", "", $3, 0));
}
|ID LP VarList error {
    yyerror(" Missing closing parenthesis ')'");
}
|ID LP error {
    yyerror(" Missing closing parenthesis ')'");
}
;
VarList : ParamDec COMMA VarList {
    $$ = createNode("VarList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
| ParamDec {
    $$ = createNode("VarList", "", $1->line, 1, $1);
}
ParamDec : Specifier VarDec {
    $$ = createNode("ParamDec", "", $1->line, 2, $1, $2);
}
;
/* statement */
CompSt : LC DefList StmtList RC {
    $$ = createNode("CompSt", "", $1, 4, createNode("LC", "", $1, 0), $2, $3, createNode("RC", "", $4, 0));
}
;
StmtList : Stmt StmtList {
    $$ = createNode("StmtList", "", $1->line, 2, $1, $2);
}
|  {
    $$ = createNode("StmtList", "", 0, 0);
    $$->empty = true;
}
;
Stmt : Exp SEMI {
    $$ = createNode("Stmt", "", $1->line, 2, $1, createNode("SEMI", "", $2, 0));
}
| CompSt {
    $$ = createNode("Stmt", "", $1->line, 1, $1);
}
| RETURN Exp SEMI {
    $$ = createNode("Stmt", "", $1, 3, createNode("RETURN", "", $1, 0), $2, createNode("SEMI", "", $3, 0));
}
| IF LP Exp RP Stmt %prec LOWER {
    $$ = createNode("Stmt", "", $1, 5, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", $1, 7, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5, createNode("ELSE", "", $6, 0), $7);
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", $1, 5, createNode("WHILE", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
}
| Exp error {
    yyerror(" Missing semicolon ';'");
}
| RETURN Exp error {
    yyerror(" Missing semicolon ';'");
}
| ErrorStmt Exp RP Stmt {}
| ErrorStmt Stmt %prec LOWER {}
| ErrorStmt Stmt ELSE Stmt {}
;
ErrorStmt: IF LP Exp error{
    yyerror(" Missing closing parenthesis ')'");
}
| WHILE LP Exp error {
    yyerror(" Missing closing parenthesis ')'");
}
| WHILE error {
    yyerror(" Missing opening parenthesis '('");
}
| IF error {
    yyerror(" Missing opening parenthesis '('");
}
;
/* local definition */
DefList : Def DefList {
    $$ = createNode("DefList", "", $1->line, 2, $1, $2);
}
|  {
    $$ = createNode("DefList", "", 0, 0);
    $$->empty = true;
}
;
Def : Specifier DecList SEMI {
    $$ = createNode("Def", "", $1->line, 3, $1, $2, createNode("SEMI", "", $3, 0));
}
| Specifier DecList error {
    yyerror(" Missing semicolon ';'");
}
| error DecList SEMI {
    yyerror(" Missing Specifier");
}
;
DecList : Dec {
    $$ = createNode("DecList", "", $1->line, 1, $1);
}
| Dec COMMA DecList {
    $$ = createNode("DecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
;
Dec : VarDec {
    $$ = createNode("Dec", "", $1->line, 1, $1);
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);    
}
;
/* Expression */
Exp : Exp ASSIGN Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
}
| Exp AND Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("AND", "", $2, 0), $3);
}
| Exp OR Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("OR", "", $2, 0), $3);
}
| Exp LT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LT", "", $2, 0), $3);
}
| Exp LE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LE", "", $2, 0), $3);
}
| Exp GT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GT", "", $2, 0), $3);
}
| Exp GE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GE", "", $2, 0), $3);
}
| Exp NE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("NE", "", $2, 0),$3);
}
| Exp EQ Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("EQ", "", $2, 0), $3);
}
| Exp PLUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("PLUS", "", $2, 0), $3);
}
| Exp MINUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MINUS", "", $2, 0),$3);
}
| Exp MUL Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MUL", "", $2, 0), $3);
}
| Exp DIV Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DIV", "", $2, 0), $3);
}
| LP Exp RP {
    $$ = createNode("Exp", "", $1, 3, createNode("LP", "", $1, 0), $2, createNode("RP", "", $3, 0));
}
| MINUS Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("MINUS", "", $1, 0), $2);
}
| NOT Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("NOT", "", $1, 0), $2);
}
| ID LP RP {
    $$ = createNode("Exp", "", $1.line, 3, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $1.line, 0), createNode("RP", "", $1.line, 0));
}
| Exp LB Exp RB {
    $$ = createNode("Exp", "", $1->line, 4, $1, createNode("LB", "", $2, 0), $3, createNode("RB", "", $4, 0));
}
| Exp DOT ID {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DOT", "", $2, 0), createNode("ID", $3.string, $3.line, 0));
}
| ID {
    $$ = createNode("Exp", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
}
| INT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("INT", $1.string, $1.line, 0));
}
| FLOATNUM {
    $$ = createNode("Exp", "", $1.line, 1, createNode("FLOAT", $1.string, $1.line, 0));
}
| CHAR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("CHAR", $1.string, $1.line, 0));
}
| STR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("STR", $1.string, $1.line, 0));
}
| ID LP Args RP {
    $$ = createNode("Exp", "", $1.line, 4, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $2, 0));
}
| ID LP Args error {
    yyerror(" Missing closing parenthesis ')'");
}
| ID LP error {
    yyerror(" Missing closing parenthesis ')'");
}
| Exp LB Exp error {
    yyerror(" Missing closing square bracket ']'");
}
| LP Exp error {
    yyerror(" Missing closing parenthesis ')'");
}
;
Args : Exp COMMA Args {
    $$ = createNode("Args", "", $1->line, 3, $1, createNode("COMMA", "", 0, 0), $3);
}
| Exp {
    $$ = createNode("Args", "", $1->line, 1, $1);
}
;
INT: DECINT{$$.string = strdup($1.string);
$$.line = $1.line;}
| HEXINT {$$.string = strdup(convertToDec($1.string));
$$.line = $1.line;}
;
CHAR: PCHAR {$$.string = strdup($1.string);
$$.line = $1.line;}
| HEXCHAR {$$.string = strdup($1.string);
$$.line = $1.line;}
;
%%
Type* checkExp(TreeNode* Exp, TypeTable* subTable){
    if(Exp->numChildren == 3){
        Type* left = checkExp(Exp->children[0], subTable);
        Type* right = checkExp(Exp->children[2], subTable);
        if(strcmp(Exp->children[1]->type, "ASSIGN") == 0){
            if(Exp->children[0]->numChildren == 1 && strcmp(Exp->children[2]->children[0]->type, "ID") != 0){
                typeError("rvalue appears on the left-side of assignment", 6, Exp->children[1]->line);
                return NULL;
            }
            if(Exp->children[2]->numChildren == 1 && strcmp(Exp->children[2]->children[0]->type, "ID") != 0){
                right = (Type*)malloc(sizeof(Type));
                right->category = PRIMITIVE;
                char* typeName = Exp->children[2]->children[0]->type;
                if(strcmp(typeName, "INT") == 0){
                    if(left != NULL && left->category == PRIMITIVE && left->primitive == FLOAT){
                        right->primitive = FLOAT;
                    }else{
                        right->primitive = INT;
                    }
                }else if(strcmp(typeName, "FLOAT") == 0){
                    right->primitive = FLOAT;
                }else if(strcmp(typeName, "CHAR") == 0){
                    right->primitive = CHAR;
                }
                right->init = 1;
            }
            if(left == NULL || right == NULL){
                typeError("unmatching type on both sides of assignment", 5, Exp->children[1]->line);
                return NULL;
            }
            if(checkType(left, right) == 1){
                typeError("unmatching type on both sides of assignment", 5, Exp->children[1]->line);
            }else{
                left->init = 1;
                return left;
            }
        }else if(strcmp(Exp->children[1]->type, "PLUS") == 0 || strcmp(Exp->children[1]->type, "MINUS") == 0 || strcmp(Exp->children[1]->type, "MUL") == 0 || strcmp(Exp->children[1]->type, "DIV") == 0){
            if(Exp->children[0]->numChildren == 1 && strcmp(Exp->children[0]->children[0]->type, "ID") != 0){
                left = (Type*)malloc(sizeof(Type));
                left->category = PRIMITIVE;
                char* typeName = Exp->children[2]->children[0]->type;
                if(strcmp(typeName, "INT") == 0){
                    left->primitive = INT;
                }else if(strcmp(typeName, "FLOAT") == 0){
                    left->primitive = FLOAT;
                }else if(strcmp(typeName, "CHAR") == 0){
                    left->primitive = CHAR;
                }
                left->init = 1;
            }
            if(Exp->children[2]->numChildren == 1 && strcmp(Exp->children[2]->children[0]->type, "ID") != 0){
                right = (Type*)malloc(sizeof(Type));
                right->category = PRIMITIVE;
                char* typeName = Exp->children[2]->children[0]->type;
                if(strcmp(typeName, "INT") == 0){
                    right->primitive = INT;
                }else if(strcmp(typeName, "FLOAT") == 0){
                    right->primitive = FLOAT;
                }else if(strcmp(typeName, "CHAR") == 0){
                    right->primitive = CHAR;
                }
                right->init = 1;
            }
            if(left == NULL || right == NULL){
                typeError("unmatching operand", 7, Exp->children[1]->line);
                return NULL;
            }
            if(left->category == PRIMITIVE && right->category == PRIMITIVE){
                int wrong = 0;
                if(left->primitive != right->primitive){
                    wrong = 1;
                    typeError("unmatching operand", 7, Exp->children[1]->line);
                }
                if(left->init == 0 || right->init == 0){
                    wrong = 1;
                    typeError("binary operation on non-nunmber varibles", 7, Exp->line);                
                }
                if(wrong == 0){
                    return left;
                }
            }else{
                typeError("unmatching operand", 7, Exp->children[1]->line);
            }
        }else if(strcmp(Exp->children[1]->type, "AND") == 0 || strcmp(Exp->children[1]->type, "OR") == 0){
            if(Exp->children[0]->numChildren == 1 && strcmp(Exp->children[0]->children[0]->type, "ID") != 0){
                left = (Type*)malloc(sizeof(Type));
                left->category = PRIMITIVE;
                char* typeName = Exp->children[2]->children[0]->type;
                if(strcmp(typeName, "INT") == 0){
                    left->primitive = INT;
                }else if(strcmp(typeName, "FLOAT") == 0){
                    left->primitive = FLOAT;
                }else if(strcmp(typeName, "CHAR") == 0){
                    left->primitive = CHAR;
                }
                left->init = 1;
            }
            if(Exp->children[2]->numChildren == 1 && strcmp(Exp->children[2]->children[0]->type, "ID") != 0){
                right = (Type*)malloc(sizeof(Type));
                right->category = PRIMITIVE;
                char* typeName = Exp->children[2]->children[0]->type;
                if(strcmp(typeName, "INT") == 0){
                    right->primitive = INT;
                }else if(strcmp(typeName, "FLOAT") == 0){
                    right->primitive = FLOAT;
                }else if(strcmp(typeName, "CHAR") == 0){
                    right->primitive = CHAR;
                }
                right->init = 1;
            }
            if(left == NULL || right == NULL){
                typeError("unmatching operand", 7, Exp->children[1]->line);
                return NULL;
            }
            if(left->category == PRIMITIVE && right->category == PRIMITIVE && left->primitive == INT && right->primitive == INT){
                if(left->primitive != right->primitive){
                    typeError("unmatching operand", 5, Exp->children[1]->line);
                }
            }else{
                typeError("unmatching operand", 5, Exp->children[1]->line);
            }
        }else if(strcmp(Exp->children[1]->type, "DOT") == 0){
            if(strcmp(Exp->children[2]->type, "ID") == 0){
                char* attrName = Exp->children[2]->value;
                Type* type = checkExp(Exp->children[0], subTable);
                if(type->category == STRUCTURE){
                    FieldList* curField = type->structure;
                    while(curField != NULL){
                        if(strcmp(curField->name, attrName) == 0){
                            return curField->type;
                        }
                        curField = curField->next;
                    }
                    typeError("accessing an undefined structure member", 14, Exp->children[1]->line);
                }else{
                    typeError("accessing with non-struct variable", 13, Exp->children[1]->line);
                }
                return type;
            }
        }
    }else if(Exp->numChildren == 2){
        Type* type = checkExp(Exp->children[1], subTable);
        if(strcmp(Exp->children[0]->type, "MINUS") == 0 || strcmp(Exp->children[0]->type, "NOT") == 0){
            if(type->category == PRIMITIVE && type->primitive == INT){
                return type;
            }else{
                typeError("unmatching operand", 7, Exp->children[0]->line);
            }
        }
    }else if(Exp->numChildren == 1){
        if(strcmp(Exp->children[0]->type, "ID") == 0){
            char* name = Exp->children[0]->value;
            Type* type;
            if(isContains(subTable, name)) type = getType(subTable, name);
            else if(isContains(typeTable, name)) type = getType(typeTable, name);
            else{
                char errorMsg[50];
                strcpy(errorMsg, name);
                strcpy(errorMsg + strlen(name), " is used without a definition");
                typeError(errorMsg, 1, Exp->children[0]->line);
            }
            return type;
        }else{
            Type* type = checkExp(Exp->children[0], subTable);
            return type;
        }
    }else if(Exp->numChildren == 4){
        if(strcmp(Exp->children[1]->type, "LB") == 0){
            Type* type = checkExp(Exp->children[0], subTable);
            TreeNode* index = Exp->children[2];
            Type* indexType = getIndexType(index, subTable);
            if(indexType == NULL || indexType->category != PRIMITIVE || indexType->primitive != INT){
                typeError("indexing by non-integer", 12, Exp->children[1]->line);
            }else if(type->category == ARRAY){
                return type->array->base;
            }else{
                typeError("indexing on non-array variable", 10, Exp->children[1]->line);
            }
        }
    }
    return NULL;
}

Type* getIndexType(TreeNode* Exp, TypeTable* subTable){
    if(Exp->numChildren == 1){
        if(strcmp(Exp->children[0]->type, "ID") == 0){
            char* name = Exp->children[0]->value;
            if(isContains(subTable, name)){
                Type* type = getType(subTable, name);
                return type;
            }else if(isContains(typeTable, name)){
                Type* type = getType(typeTable, name);
                return type;
            }else{
                char errorMsg[50];
                strcpy(errorMsg, name);
                strcpy(errorMsg + strlen(name), " is used without a definition");
                typeError(errorMsg, 1, Exp->children[0]->line);
            }
        }else if(strcmp(Exp->children[0]->type, "INT") == 0 || strcmp(Exp->children[0]->type, "FLOAT") == 0 || strcmp(Exp->children[0]->type, "CHAR") == 0){
            Type* type = (Type*)malloc(sizeof(Type));
            type->category = PRIMITIVE;
            type->primitive = INT;
            return type;
        }
    }else if(Exp->numChildren == 4){
        Type* type = getIndexType(Exp->children[0], subTable);
        Type* indexType = getIndexType(Exp->children[2], subTable);
        if(indexType == NULL || indexType->category != PRIMITIVE || indexType->primitive != INT){
            return NULL;
        }
        return type->array->base;
    }
    return NULL;
}

Type* processStruct(TreeNode* structSpecifier){
    Type* type = (Type*)malloc(sizeof(Type));
    TypeTable* innerTable = (TypeTable*)malloc(sizeof(TypeTable));
    if(structSpecifier->numChildren == 5){
        //完整定义
        strcpy(type->name, structSpecifier->children[1]->value);
        type->category = STRUCTURE;
        type->structure = (FieldList*)malloc(sizeof(FieldList));
        FieldList* curField = type->structure;
        TreeNode* defListNode = structSpecifier->children[3];
        ListNode** defList = (ListNode**)malloc(sizeof(ListNode*));
        *defList = NULL;
        findNode(defListNode, defList, "Def");
        ListNode* curNode = *defList;
        while(curNode != NULL){
            TreeNode* specifier = curNode->node->children[0];
            if(strcmp(specifier->children[0]->type, "TYPE") == 0){
                ListNode** varDecList = (ListNode**)malloc(sizeof(ListNode*));
                *varDecList = NULL;
                findNode(curNode->node, varDecList, "VarDec");
                ListNode* curVar = *varDecList;
                while(curVar != NULL){
                    char* name;
                    Type* subType = (Type*)malloc(sizeof(Type));
                    if(curVar->node->numChildren == 1){
                        //普通变量
                        TreeNode* id = curVar->node->children[0];
                        name = id->value;
                        subType->category = PRIMITIVE;
                        char* typeName = specifier->children[0]->value;
                        if(strcmp(typeName, "int") == 0){
                            subType->primitive = INT;
                        }else if(strcmp(typeName, "float") == 0){
                            subType->primitive = FLOAT;
                        }else if(strcmp(typeName, "char") == 0){
                            subType->primitive = CHAR;
                        }
                        strcpy(subType->name, name);
                        int wrong = insertIntoTypeTable(innerTable, name, subType);
                        if(wrong == 1){
                            char errorMsg[50];
                            strcpy(errorMsg, "variable \"");
                            strcpy(errorMsg + 10, name);
                            strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
                            typeError(errorMsg, 3, id->line);
                        }
                        strcpy(curField->name, name);
                        curField->type = subType;
                        curField->next = (FieldList*)malloc(sizeof(FieldList));
                        curField = curField->next;
                    }else{
                        //数组
                        processArray(curVar->node, subType, specifier);
                        int wrong = insertIntoTypeTable(innerTable, subType->name, subType);
                        if(wrong == 1){
                            char errorMsg[50];
                            strcpy(errorMsg, "variable \"");
                            strcpy(errorMsg + 10, name);
                            strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
                            typeError(errorMsg, 3, curVar->node->children[2]->line);
                        }
                        curField->type = subType;
                        curField->next = (FieldList*)malloc(sizeof(FieldList));
                        curField = curField->next;
                    }
                    curVar = curVar->next;
                }
                freeList(varDecList);
            }else{
                //结构体
                ListNode** varDecList = (ListNode**)malloc(sizeof(ListNode*));
                *varDecList = NULL;
                findNode(curNode->node, varDecList, "VarDec");
                ListNode* curVar = *varDecList;
                while(curVar != NULL){
                    Type* subType = getType(typeTable, specifier->children[0]->children[1]->value);
                    char* name;
                    name = curVar->node->children[0]->value;
                    strcpy(subType->name, name);
                    int wrong = insertIntoTypeTable(innerTable, name, subType);
                    if(wrong == 1){
                        char errorMsg[50];
                        strcpy(errorMsg, "variable \"");
                        strcpy(errorMsg + 10, name);
                        strcpy(errorMsg + 10 + strlen(name), "\" is redefined in the same scope");
                        typeError(errorMsg, 3, specifier->line);
                    }
                    strcpy(curField->name, name);
                    curField->type = subType;
                    curField->next = (FieldList*)malloc(sizeof(FieldList));
                    curField = curField->next;
                    curVar = curVar->next;
                }
            }
            curNode = curNode->next;
        }
        freeList(defList);
    }else{
        //只有定义无声明
        strcpy(type->name, structSpecifier->children[1]->value);
        type->category = STRUCTURE;
        type-> structure = NULL;
    }
    return type;
}

void processArray(TreeNode* varDec, Type* type, TreeNode* specifier){
    type->category = ARRAY;
    type->array = (Array*)malloc(sizeof(Array));
    type->array->base = (Type*)malloc(sizeof(Type));
    type->array->size = atoi(varDec->children[2]->value);
    Type* curType = type->array->base;
    varDec = varDec->children[0];
    while(varDec->numChildren != 1){
        curType->category = ARRAY;
        curType->array = (Array*)malloc(sizeof(Array));
        curType->array->base = (Type*)malloc(sizeof(Type));
        type->array->size = atoi(varDec->children[2]->value);
        curType = curType->array->base;
        varDec = varDec->children[0];
    }
    char* name = varDec->children[0]->value;
    if(strcmp(specifier->children[0]->type, "TYPE") == 0){
        curType->category = PRIMITIVE;
        char* typeName = specifier->children[0]->value;
        if(strcmp(typeName, "int") == 0){
            curType->primitive = INT;
        }else if(strcmp(typeName, "float") == 0){
            curType->primitive = FLOAT;
        }else if(strcmp(typeName, "char") == 0){
            curType->primitive = CHAR;
        }
    }
    strcpy(type->name, name);
}

void findNode(TreeNode* node, ListNode** list, char* type){
    if(node == NULL) return;
    if(strcmp(node->type, type) == 0) {
        insertListNode(list, node);
    }
    for(int i = 0; i < node->numChildren; i++) {
        findNode(node->children[i], list, type);
    }
}

void findNodeExcept(TreeNode* node, ListNode** list, char* type, char* except){
    if(node == NULL) return;
    if(strcmp(node->type, type) == 0) {
        insertListNode(list, node);
    }
    if(strcmp(node->type, except) == 0) return;
    for(int i = 0; i < node->numChildren; i++) {
        findNode(node->children[i], list, type);
    }
}

void freeTree(TreeNode* node){
    if(node == NULL) return;
    int num = node->numChildren;
    for(int i = 0; i < num; i++){
        freeTree(node->children[i]);
    }
    free(node->type);
    free(node->value);
    free(node->children);
    free(node);
}

TreeNode* createNode(char* type, char* value, int line, int numChildren, ...) {
    TreeNode* newNode = (TreeNode*)malloc(sizeof(TreeNode));
    newNode->type = strdup(type);
    newNode->value = strdup(value);
    newNode->line = line;
    newNode->numChildren = numChildren;
    newNode->empty = false;
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

void getOutputPath(const char *input_path, char *output_path, size_t output_path_size) {
    char *file_extension = strstr(input_path, ".spl");
    if (file_extension != NULL) {
        size_t new_filename_length = file_extension - input_path;
        snprintf(output_path, output_path_size, "%.*s%s", (int)new_filename_length, input_path, ".out");
    } else {
        strncpy(output_path, input_path, output_path_size);
    }
}

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
            fprintf(output_file, "  ");
            printf("  ");
        }
        if(node->numChildren == 0){
            if(strlen(node->value) == 0){
                fprintf(output_file, "%s\n", node->type);
                printf("%s\n", node->type);
            }else{
                fprintf(output_file, "%s: %s\n", node->type, node->value);
                printf("%s: %s\n", node->type, node->value);
            }
        }
        else {
            fprintf(output_file, "%s (%d)\n", node->type, node->line);
            printf("%s (%d)\n", node->type, node->line);
        }
    }

    for (int i = 0; i < node->numChildren; i++) {
        printParseTree(node->children[i], level + 1);
    }
}

int typeError(const char *msg, int type, int line){
    printf("Error type %d at Line %d:%s\n", type, line, msg);
    fprintf(output_file, "Error type %d at Line %d:%s\n",type, line, msg);
    return 0;
}

int yyerror(const char *msg) {
    char* syntax_error = "syntax error";
    if(strcmp(msg, syntax_error) != 0){        
        printf("Error type B at Line %d:%s\n", line, msg);
        fprintf(output_file, "Error type B at Line %d:%s\n", line, msg);
    }
    error = true;
    return 0;
}
/* int main() {
    yyparse();
} */
int main(int argc, char **argv){
    char *file_path;
    typeTable = (TypeTable*)malloc(sizeof(TypeTable));
    memset(typeTable->isFilled, 0, sizeof(typeTable->isFilled));
    if(argc < 2){
        fprintf(stderr, "Usage: %s <file_path>\n", argv[0]);
        return EXIT_FAIL;
    } else if(argc == 2){
        file_path = argv[1];
        char output_file_path[256];
        getOutputPath(file_path, output_file_path, sizeof(output_file_path));
        output_file = fopen(output_file_path, "w");
        if(!(yyin = fopen(file_path, "r"))){
            perror(argv[1]);
            return EXIT_FAIL;
        }
        yyparse();
        fclose(output_file);
        free(typeTable);
        return EXIT_OK;
    } else{
        fputs("Too many arguments! Expected: 2.\n", stderr);
        return EXIT_FAIL;
    }
}