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
    int typeError(const char *msg, int type);
    int yyerror(const char *);
    TypeTable* typeTable;
    ListNode* findTerminals(TreeNode* node, ListNode* list);
    void findNode(TreeNode* node, ListNode* list, char* type);
    void printParseTree(TreeNode* node, int level);
    void getOutputPath(const char *input_path, char *output_path, size_t output_path_size);
    TreeNode* createNode(char* type, char* value, int line, int numChildren, ...);
    TreeNode* convertNull(TreeNode* node);
    char num[50];
    void processArray(TreeNode* varDec, Type* type, TreeNode* specifier);
    void processStruct(TreeNode* structSpecifier, Type* type);
    void freeTree(TreeNode* node);

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
    $$ = createNode("ExtDef", "", $1->line, 3, $1, $2, createNode("SEMI", "", $3, 0));
    //add primitive type to type table
    Type* type = (Type*)malloc(sizeof(Type));
    TreeNode* cur = $2;
    ListNode* varDecList = NULL;
    findNode(cur, varDecList, "VarDec");
    ListNode* curVar = varDecList;
    char* name;
    while(curVar != NULL){
        Type* type = (Type*)malloc(sizeof(Type));
        if(curVar->node->numChildren == 1){
            //普通变量
            name = curVar->node->children[0]->value;
            strcpy(type->name, name);
            type->category = PRIMITIVE;
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
            name = curVar->node->children[2]->value;
            strcpy(type->name, name);
            type->category = ARRAY;
            type->array = (Array*)malloc(sizeof(Array));
            Type* base = (Type*)malloc(sizeof(Type));
            int size = atoi(curVar->node->children[2]->value);
            processArray(curVar->node, base, $1);
            type->array->base = base;
            type->array->size = size;
        }
        insertIntoTypeTable(typeTable, name, type);
        curVar = curVar->next;
    }
    freeList(varDecList);
}
| Specifier SEMI {
    $$ = createNode("ExtDef", "", $1->line, 2, $1, createNode("SEMI", "", $2, 0));
    //add struct type to type table
    TreeNode* structSpecifier = $1->children[0];
    Type* type = (Type*)malloc(sizeof(Type));
    
}
| Specifier FunDec CompSt {
    $$ = createNode("ExtDef", "", $1->line, 3, $1, $2, $3);
}
| Specifier error {
    //yyerror(" Missing semicolon ';'");
}
| Specifier ExtDecList error {
    //yyerror(" Missing semicolon ';'");
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
    //yyerror(" Missing closing square bracket ']'");
}
;
FunDec : ID LP VarList RP {
    $$ = createNode("FunDec", "", $1.line, 4, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0));
}
| ID LP RP {
    $$ = createNode("FunDec", "", $1.line, 3, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), createNode("RP", "", $3, 0));
}
|ID LP VarList error {
    //yyerror(" Missing closing parenthesis ')'");
}
|ID LP error {
    //yyerror(" Missing closing parenthesis ')'");
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
    //yyerror(" Missing semicolon ';'");
}
| RETURN Exp error {
    //yyerror(" Missing semicolon ';'");
}
| ErrorStmt Exp RP Stmt {}
| ErrorStmt Stmt %prec LOWER {}
| ErrorStmt Stmt ELSE Stmt {}
;
ErrorStmt: IF LP Exp error{
    //yyerror(" Missing closing parenthesis ')'");
}
| WHILE LP Exp error {
    //yyerror(" Missing closing parenthesis ')'");
}
| WHILE error {
    //yyerror(" Missing opening parenthesis '('");
}
| IF error {
    //yyerror(" Missing opening parenthesis '('");
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
    //yyerror(" Missing semicolon ';'");
}
| error DecList SEMI {
    //yyerror(" Missing Specifier");
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
    ListNode* idList = NULL;
    findNode($3, idList, "ID");
    ListNode* curId = idList;
    while(curId != NULL){
        char* name = curId->node->value;
        int len = strlen(name);
        char* errorMsg = malloc(50);
        strcpy(errorMsg, name);
        strcpy(errorMsg + len, " is used without a definition");
        if(!isContains(typeTable, name)){
            typeError(errorMsg, 1);
        }
    }
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
    //yyerror(" Missing closing parenthesis ')'");
}
| ID LP error {
    //yyerror(" Missing closing parenthesis ')'");
}
| Exp LB Exp error {
    //yyerror(" Missing closing square bracket ']'");
}
| LP Exp error {
    //yyerror(" Missing closing parenthesis ')'");
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
void processStruct(TreeNode* structSpecifier, Type* type){
        if(structSpecifier->numChildren == 2){
            //同时使用struct ID和别名ID,Type类型中存真名，table中存进别名
            strcpy(type->name, structSpecifier->children[1]->value);
            type->category = STRUCTURE;
            type->structure = (FieldList*)malloc(sizeof(FieldList));
            FieldList* curField = type->structure;
            TreeNode* defListNode = structSpecifier->children[3];
            ListNode* defList = NULL;
            findNode(defListNode, defList, "Def");
            ListNode* curNode = defList;
            while(curNode != NULL){
                TreeNode* specifier = curNode->node->children[0];
                if(strcmp(specifier->children[0]->type, "TYPE") == 0){
                    ListNode* varDecList = NULL;
                    findNode(curNode->node, varDecList, "VarDec");
                    ListNode* curVar = varDecList;
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
                            strcpy(curField->name, name);
                            curField->type = subType;
                            curField->next = (FieldList*)malloc(sizeof(FieldList));
                            curField = curField->next;
                            //struct内部变量
                            insertIntoTypeTable(typeTable, name, subType);
                        }else{
                            //数组
                            ListNode* idList = NULL;
                            findNode(curVar->node, idList, "ID");
                            TreeNode* id = idList->node;
                            strcpy(name, id->value);
                            strcpy(subType->name, name);
                            subType->category = ARRAY;
                            subType->array = (Array*)malloc(sizeof(Array));
                            Type* base = (Type*)malloc(sizeof(Type));
                            int size = atoi(curVar->node->children[2]->value);
                            if(strcmp(curVar->node->children[0]->children[0]->type, "ID") == 0){
                                base->category = PRIMITIVE;
                                char* typeName = specifier->children[0]->value;
                                if(strcmp(typeName, "int") == 0){
                                    base->primitive = INT;
                                }else if(strcmp(typeName, "float") == 0){
                                    base->primitive = FLOAT;
                                }else if(strcmp(typeName, "char") == 0){
                                    base->primitive = CHAR;
                                }
                            }else{
                                processArray(curVar->node->children[0], base, specifier);
                            }
                            subType->array->base = base;
                            subType->array->size = size;
                            insertIntoTypeTable(typeTable, name, subType);
                            freeList(idList);
                        }
                    }
                    freeList(varDecList);
                }else{
                    //struct嵌套
                    Type* subType = (Type*)malloc(sizeof(Type));
                    processStruct(specifier->children[0], subType);
                    ListNode* varDecList = NULL;
                    findNode(curNode->node, varDecList, "VarDec");
                    ListNode* curVar = varDecList;
                    while(curVar != NULL){
                        char* name;
                        if(curVar->node->numChildren == 1){
                            TreeNode* id = curVar->node->children[0];
                            name = id->value;
                        }
                        insertIntoTypeTable(typeTable, name, subType);
                    }
                    freeList(varDecList);
                }
            }
            //struct本身
            insertIntoTypeTable(typeTable, structSpecifier->children[1]->value, type);
            freeList(defList);
        }
    }

void processArray(TreeNode* varDec, Type* type, TreeNode* specifier){
        ListNode* idList = NULL;
        findNode(varDec, idList, "ID");
        TreeNode* id = idList->node;
        char* name;
        name = id->value;
        strcpy(type->name, name);
        type->category = ARRAY;
        type->array = (Array*)malloc(sizeof(Array));
        Type* base = (Type*)malloc(sizeof(Type));
        int size = atoi(varDec->children[2]->value);
        if(strcmp(varDec->children[0]->children[0]->type, "ID") == 0){
            base->category = PRIMITIVE;
            //默认不为struct数组
            char* typeName = specifier->children[0]->value;
            if(strcmp(typeName, "int") == 0){
                base->primitive = INT;
            }else if(strcmp(typeName, "float") == 0){
                base->primitive = FLOAT;
            }else if(strcmp(typeName, "char") == 0){
                base->primitive = CHAR;
            }
        }else{
            processArray(varDec->children[0], base, specifier);
        }
        type->array->base = base;
        type->array->size = size;
        freeList(idList);
    }

void findNode(TreeNode* node, ListNode* list, char* type){
    if(node == NULL) return;
    if(strcmp(node->type, type) == 0) {
        insertListNode(list, node);
    }
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
        //printf("the node is %s %s %d\n", type, value, line);
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

int typeError(const char *msg, int type){
    printf("Error type %d at Line %d:%s\n", type, line, msg);
    fprintf(output_file, "Error type %d at Line %d:%s\n",type, line, msg);
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