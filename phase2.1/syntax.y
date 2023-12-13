%{
    #include <stdio.h>
    #include <stdbool.h>
    #include <string.h>
    #include "lex.yy.c"
    #include "script/tree_node.h"
    #include "script/lex_interface.h"
    #include "script/type_table.c"
    #define MAX_DEPTH 100

    // phase1
    int yydebug = 1;
    char* convertToDec(char*);
    int yyerror(const char *);
    TreeNode* createNode(char* type, char* value, int line, int numChildren, ...); 
    TreeNode* convertNull(TreeNode* node) ;
    void printParseTree(TreeNode* node, int level);
    void getOutputPath(const char *input_path, char *output_path, size_t output_path_size);
    char num[50];
    void freeTree(TreeNode* node);

    //phase2
    int my_line;
    TypeTable* scopeStack[MAX_DEPTH];
    int scopeDepth;
    Category expStack[MAX_DEPTH];
    int expDepth;
    // type: 在创建任意一个type时都创建在这里，在insert后置NULL
    Type* type;
    Type* type2;
    // functionType: 在创建函数时创建在这里，通过insertFunction插入，随后置NULL
    Type* functionType;
    Function* function;
    CategoryList* cateList;
    TypeList* structList;

    bool lvalue;
    // structureType: 在创建Structure时创建在这里，通过insertStruct插入，随后置NULL
    Type* structureType;
    // 用于在创建带参函数时，在识别到FunDec而非"{"时执行push
    bool creatingFunction;
    bool creatingStruct;
    bool declaringStruct;

    void pushExp(Category exp);
    Category popExp();

    void init(Category category);
    void initFunction(char* name);
    void initStruct(char* name);
    void initArray();

    bool insert();
    bool insertFunction();
    bool insertStruct();
    void clear();
    void setNull();
    void clearArray();
    bool recreate();

    Category stringToCategory(char* category);

    bool check(char* name);
    Type* get(char* name);
    bool checkExp(Category category1, Category category2);

    void freeLastTable();
    void printAllTable();

    void intOperate(char* op);
    void boolOperate(char* op);
%}
%union {
    struct {
        char* string;
        int line;
    } str_line;
    struct TreeNode* node;
}
%type<str_line> INT CHAR
%token<str_line> TYPE ID FLOAT DECINT HEXINT PCHAR HEXCHAR STR
%token<str_line.line> LC RC SEMI COMMA STRUCT RETURN WHILE IF
%type<node> Program ExtDefList ExtDef ExtDecList Specifier StructSpecifier VarDec FunDec VarList ParamDec CompSt StmtList Stmt DefList Def DecList Dec Exp Args ErrorStmt FunID StructDec
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
}
| // Specifier SEMI
    StructSpecifier SEMI {
    $$ = createNode("ExtDef", "", $1->line, 2, $1, createNode("SEMI", "", $2, 0));
    // default struct
}
| Specifier FunDec CompSt {
    $$ = createNode("ExtDef", "", $1->line, 3, $1, $2, $3);
    printf("info line %d: function end\n", line);
    functionType = NULL;
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
    insert();
    recreate();
}
|
// modified: can't handle VarDec COMMA ExtDecList, changed to:
    ExtDecList COMMA VarDec{
    $$ = createNode("ExtDecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
    insert();
    recreate();
}
;
/* specifier */
Specifier : TYPE {
    $$ = createNode("Specifier", "", $1.line, 1, createNode("TYPE", $1.string, $1.line, 0));
    init(stringToCategory($1.string));
}
| StructDec {
    $$ = createNode("Specifier", "", $1->line, 1, $1);
    type = structureType;
    structureType = NULL;
    creatingStruct = false;
    declaringStruct = true;
}
;

StructSpecifier : StructDec LC DefList RC {
    $$ = createNode("StructSpecifier", "", $1 -> line, 5, $1 -> children[0], $1 -> children[1], createNode("LC", "", $2, 0), $3, createNode("RC", "", $4, 0));
    insertStruct();
    structureType = NULL;
}
// modified: when using specifier to declare, use StructDec instead
// | StructDec {
//    $$ = createNode("StructSpecifier", "", $1 -> line, 2, $1 -> children[0], $1 -> children[1]);
//}
;
/* declarator */
// modified: add StructDec
StructDec : STRUCT ID {
    $$ = createNode("StructDec", "", $1, 2, createNode("STRUCT", "", $1, 0), createNode("ID", $2.string, $2.line, 0));
    initStruct($2.string);
    creatingStruct = true;
}
;

VarDec : ID {
    $$ = createNode("VarDec", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    if (declaringStruct){
        Type* result = get(type -> name);
        if(!result -> category == STRUCTURE){
            printf("error");
        }else{
            type -> structure = result -> structure;
            setNull();
            init(STRUCTURE);
            type -> name = $1.string;
            type -> structure = result -> structure;
        }
    }else{
        type -> name = $1.string;
    }
    // printf("info line %d: creating VarDec, name: %s\n", line, type -> name);
}
| VarDec LB INT RB {
    $$ = createNode("VarDec", "", $1->line, 4, $1, createNode("LB", "", $2, 0), createNode("INT", $3.string, $3.line, 0), createNode("RB", "", $4, 0));
    initArray(atoi($3.string));
}
| VarDec LB INT error {
    yyerror(" Missing closing square bracket ']'");
}
;
FunDec : FunID LP VarList RP {
    $$ = createNode("FunDec", "", $1->line, 4, $1, createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0));
}
|FunID LP RP {
    $$ = createNode("FunDec", $1 -> value, $1->line, 3, $1, createNode("LP", "", $2, 0), createNode("RP", "", $3, 0));
}
|FunID LP VarList error {
    yyerror(" Missing closing parenthesis ')'");
}
|FunID LP error {
    yyerror(" Missing closing parenthesis ')'");
}
;
// modified: add FunID
FunID : ID {
    $$ = createNode("ID", $1.string, $1.line, 0);
    initFunction($1.string);
    functionType -> function -> returnCategory = type -> category;
    insertFunction();
    setNull();
    push();
    creatingFunction = true;
}
;
VarList : ParamDec COMMA VarList {
    $$ = createNode("VarList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
| ParamDec {
    $$ = createNode("VarList", "", $1->line, 1, $1);
    cateList = NULL;
}
;
ParamDec : Specifier VarDec {
    $$ = createNode("ParamDec", "", $1->line, 2, $1, $2);
    insert();
    if (functionType -> function -> varList == NULL){
        cateList = (CategoryList*)malloc(sizeof(CategoryList));
        functionType -> function -> varList = cateList;
    }else{
        cateList -> next = (CategoryList*)malloc(sizeof(CategoryList));
        cateList = cateList -> next;
    }
    cateList -> category = type -> category;
    functionType -> function -> paramNum++;
    printAllTable();
    setNull();
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
    popExp();
}
| CompSt {
    $$ = createNode("Stmt", "", $1->line, 1, $1);
}
| RETURN Exp SEMI {
    $$ = createNode("Stmt", "", $1, 3, createNode("RETURN", "", $1, 0), $2, createNode("SEMI", "", $3, 0));
    Category find = popExp();
    Category expected = functionType -> function -> returnCategory;
    if (find != expected){
        printf("Error type 8 at Line %d: incompatiable return type, except: %s, got: %s\n", line, categoryToString(expected), categoryToString(find));
    }
    printf("info line %d: returning %s\n", $1, categoryToString(find));
    if (expDepth != 0){
        printf("warning line %d: exp stack isn't clear correctly, left: %d\n", line, expDepth);
        expDepth = 0;
    }
}
| IF LP Exp RP Stmt %prec LOWER {
    $$ = createNode("Stmt", "", $1, 5, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    if (popExp()!= BOOLEAN){
        printf("error:not bool\n");
    }
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", $1, 7, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5, createNode("ELSE", "", $6, 0), $7);
    if (popExp()!= BOOLEAN){
        printf("error:not bool\n");
    }
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", $1, 5, createNode("WHILE", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    if (popExp()!= BOOLEAN){
        printf("error:not bool\n");
    }
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
    $$ -> empty = true;
}
;
Def : Specifier DecList SEMI {
    $$ = createNode("Def", "", $1->line, 3, $1, $2, createNode("SEMI", "", $3, 0));
    clear();
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
|// modified: Dec COMMA DecList
DecList COMMA Dec {
    $$ = createNode("DecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
;
Dec : VarDec {
    $$ = createNode("Dec", "", $1->line, 1, $1);
    if (creatingStruct) {
        structList = (TypeList*) malloc(sizeof(TypeList));
        structList -> type = type;
    }
    insert();
    recreate();
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    Category exp = popExp();
    if (exp != NUL && type -> category != exp) {
        printf("Error type 5 at Line %d: unmatching type on both sides of assignment, expected %s, got %s\n", line, categoryToString(type -> category), categoryToString(exp));
    }
    insert();
    recreate();
}
;

/* Expression */
Exp : Exp ASSIGN Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    if (!lvalue){
        printf("Error type 6 at Line %d: rvalue appears on the left-side of assignment\n", line);
    }
    lvalue = false;
    Category exp1 = popExp();
    Category exp2 = popExp();
    if (exp1!=exp2) {
        printf("Error type 5 at Line %d: unmatching type on both sides of assignment\n", line);
    }
}
| Exp AND Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("AND", "", $2, 0), $3);
    boolOperate("and");
    pushExp(BOOLEAN);
}
| Exp OR Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("OR", "", $2, 0), $3);
    boolOperate("or");
    pushExp(BOOLEAN);
}
| Exp LT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LT", "", $2, 0), $3);
    intOperate("less than");
    pushExp(BOOLEAN);
}
| Exp LE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LE", "", $2, 0), $3);
    intOperate("less equal");
    pushExp(BOOLEAN);
}
| Exp GT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GT", "", $2, 0), $3);
    intOperate("greater than");
    pushExp(BOOLEAN);
}
| Exp GE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GE", "", $2, 0), $3);
    intOperate("greater equal");
    pushExp(BOOLEAN);
}
| Exp NE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("NE", "", $2, 0),$3);
    intOperate("not equal");
    pushExp(BOOLEAN);
}
| Exp EQ Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("EQ", "", $2, 0), $3);
    intOperate("equal");
    pushExp(BOOLEAN);
}
| Exp PLUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("PLUS", "", $2, 0), $3);
    intOperate("plus");
    pushExp(INT);
}
| Exp MINUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MINUS", "", $2, 0),$3);
    intOperate("minus");
    pushExp(INT);
}
| Exp MUL Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MUL", "", $2, 0), $3);
    intOperate("multiply");
    pushExp(INT);
}
| Exp DIV Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DIV", "", $2, 0), $3);
    intOperate("divided by");
    pushExp(INT);
}
| LP Exp RP {
    lvalue = false;
    $$ = createNode("Exp", "", $1, 3, createNode("LP", "", $1, 0), $2, createNode("RP", "", $3, 0));
}
| MINUS Exp {
    lvalue = false;
    $$ = createNode("Exp", "", $1, 2, createNode("MINUS", "", $1, 0), $2);
    Category exp = popExp();
    printf("info line %d: minus %s \n", line, categoryToString(exp));
    if (exp != INT && exp != FLOATNUM && exp != 0){
        printf("error line %d: exp type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp));
    }
    pushExp(INT);
}
| NOT Exp {
    lvalue = false;
    $$ = createNode("Exp", "", $1, 2, createNode("NOT", "", $1, 0), $2);
    Category exp = popExp();
    printf("info line %d: not %s \n", line, categoryToString(exp));
    if (exp != BOOLEAN && exp != 0){
        printf("error line %d: exp type mismatch, expected: boolean, find: %s\n", line, categoryToString(exp));
    }
    pushExp(BOOLEAN);
}
| Exp LB Exp RB {
    lvalue = true;
    $$ = createNode("Exp", "", $1->line, 4, $1, createNode("LB", "", $2, 0), $3, createNode("RB", "", $4, 0));
    Category exp1 = popExp(), exp2 = popExp();
    if (exp1 != INT){
        printf("Error type 12 at Line %d: indexing by non-integer", line);
    }
    if (exp2 != ARRAY){
        printf("Error type 10 at line %d: indexing on non-array variable\n", line);
    }
    if (type2 -> category == ARRAY){
        type2 = type -> array -> base;
        pushExp(type2 -> array -> base -> category);
        if (type2 -> array -> base -> category == STRUCTURE){
            structureType = type2 -> array -> base;
        }
    }else {
        printf("error depth exceed");
    }
}
| Exp DOT ID {
    lvalue = true;
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DOT", "", $2, 0), createNode("ID", $3.string, $3.line, 0));
    Category exp = popExp();
    if (exp != STRUCTURE){
        printf("Error type 13 at Line %d: accessing with non-struct variable\n", line);
        pushExp(NUL);
    }else{
        if (structureType == NULL){
            printf("something is wrong\n");
        }
        Category category = structureFind(structureType -> structure -> typeList, $3.string);
        if(category == NUL){
            printf("Error type 14 at Line %d: accessing an undefined structure member\n", line);
        }
        // if (check($3.string)){
        //     Type* t = get($3.string);
        //     if (t -> category == STRUCTURE){
        //         structureType = t;
        //     }
        // }
        pushExp(category);
    }
}
| ID {
    lvalue = true;
    $$ = createNode("Exp", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    Type* result = get($1.string);
    if (result != NULL){
        if (result -> category == NUL) {
            printf("warning line %d: type had been used without definition before, name: %s\n", line, $1.string);
            pushExp(NUL);
        } else if (result -> category == ARRAY) {       
            type2 = result;
            pushExp(result -> category);
        } else if (result -> category == FUNCTION){
            printf("Error type ? at line %d: function invoked without ()\n", line);
            pushExp(result -> function -> returnCategory);
        } else if (result -> category == STRUCTURE){
            structureType = result;
            pushExp(result -> category);
        } else {
            pushExp(result -> category);
        }
    } else {
        // error: can't find id
        printf("Error type 1 at Line %d: \"%s\" is used without a definition\n", line, $1.string);
        Type* temp = (Type*)malloc(sizeof(TYPE));
        temp -> name = $1.string;
        temp -> category = NUL;
        insertIntoTypeTable(scopeStack[scopeDepth], temp, line);
        printAllTable();
        pushExp(NUL);
    }
}
| INT {
    lvalue = false;
    $$ = createNode("Exp", "", $1.line, 1, createNode("INT", $1.string, $1.line, 0));
    pushExp(INT);
}
| FLOAT {
    lvalue = false;
    $$ = createNode("Exp", "", $1.line, 1, createNode("FLOAT", $1.string, $1.line, 0));
    pushExp(FLOATNUM);
}
| CHAR {
    lvalue = false;
    $$ = createNode("Exp", "", $1.line, 1, createNode("CHAR", $1.string, $1.line, 0));
    pushExp(CHAR);
}
| STR {
    lvalue = false;
    $$ = createNode("Exp", "", $1.line, 1, createNode("STR", $1.string, $1.line, 0));
    pushExp(STRING);
}
| ID LP RP {
    lvalue = false;
    $$ = createNode("Exp", "", $1.line, 3, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $1.line, 0), createNode("RP", "", $1.line, 0));
    Type* functionType2 = get($1.string);
    if (functionType2 == NULL){
        printf("Error type 2 at Line %d: \"%s\" is invoked without a definition", line, $1.string);
        pushExp(NUL);
    }else if (functionType2 -> category != FUNCTION) {
        printf("Error type 11 at Line %d: invoking non-function variable", line);
        pushExp(functionType2 -> category);
    }else {
        if (functionType2 -> function -> paramNum != 0){
            printf("Error type 9 at Line %d: invalid argument number, except %d, got 0\n", line, functionType -> function -> paramNum);
            pushExp(functionType2 -> function -> returnCategory);
        }else {
            pushExp(functionType2 -> function -> returnCategory);
        }
        if (functionType2 -> function -> returnCategory == STRUCTURE){
            // structureType = NONONO!;
        }
    } 
    
}
| ID LP Args RP {
    lvalue = false;
    $$ = createNode("Exp", "", $1.line, 4, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $2, 0));
    int paramNum1 = function -> paramNum;
    CategoryList* varList1 = function -> varList;
    Type* functionType2 = get($1.string);
    if (functionType2 == NULL){
        printf("Error type 2 at Line %d: \"%s\" is invoked without a definition\n", line, $1.string);
        pushExp(NUL);
    }else if (functionType2 -> category != FUNCTION) {
        printf("Error type 11 at Line %d: invoking non-function variable\n", line);
        pushExp(NUL);
    }else{
        int paramNum2 = functionType2 -> function -> paramNum;
        CategoryList* varList2 = functionType2 -> function -> varList;
        if (paramNum1 != paramNum2) {
            printf("Error type 9 at Line %d: invalid argument number, except %d, got %d\n", line, paramNum1, paramNum2);
        } else { 
            while (varList1 != NULL && varList2 != NULL){
                Category category1 = varList1 -> category;
                Category category2 = varList2 -> category;
                printf("info line %d: checking category %s, %s\n", line, categoryToString(category1), categoryToString(category2));
                if (category1 != NUL &&
                    category2 != NUL &&
                    category1 != category2){
                    printf("Error type 9 at Line %d: arguments type mismatch, except %s, got %s\n", line, categoryToString(category2), categoryToString(category1));
                    break;
                }
                varList1 = varList1 -> next;
                varList2 = varList2 -> next;
            }
        }
        pushExp(functionType -> function -> returnCategory);
    }
    freeFunction(line, function);
    function = NULL;
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
    CategoryList* last = (CategoryList*)malloc(sizeof(CategoryList));
    last -> category = popExp();
    last -> next = function -> varList;
    function -> varList = last;
    function -> paramNum++;
}
| Exp {
    $$ = createNode("Args", "", $1->line, 1, $1);
    function = (Function*)malloc(sizeof(Function));
    function -> varList = (CategoryList*)malloc(sizeof(CategoryList));
    function -> varList -> category = popExp();
    function -> paramNum = 1;
}
;
INT: DECINT{$$.string = strdup($1.string); $$.line = $1.line;}
| HEXINT {$$.string = strdup(convertToDec($1.string)); $$.line = $1.line;}
;
CHAR: PCHAR {$$.string = strdup($1.string); $$.line = $1.line;}
| HEXCHAR {$$.string = strdup($1.string); $$.line = $1.line;}
;

%%
// phase1
TreeNode* createNode(char* type, char* value, int line, int numChildren, ...) {
    my_line = line;
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

TreeNode* convertNull(TreeNode* node) {
    node->empty = true;
    return node;
}

void printParseTree(TreeNode* node, int level) {
    if(node == NULL) return;
    if(!node->empty){
        for (int i = 0; i < level; i++) {
            printf("  ");
        }
        if(node->numChildren == 0){
            if(strlen(node->value) == 0){
                printf("%s\n", node->type);
            }else{
                printf("%s: %s\n", node->type, node->value);
            }
        }
        else {
            printf("%s (%d)\n", node->type, node->line);
        }
    }

    for (int i = 0; i < node->numChildren; i++) {
        printParseTree(node->children[i], level + 1);
    }
}

int yyerror(const char *msg) {
    char* syntax_error = "syntax error";
    if(strcmp(msg, syntax_error) != 0){        
        printf("error type B at Line %d:%s\n", line, msg);
    }
    error = true;
    return 0;
}

int main(int argc, char **argv){
    char *file_path;
    
    scopeStack[0] = (TypeTable*)malloc(sizeof(TypeTable));
    scopeDepth = 0;
    // memset(typeTable -> isFilled, 0, sizeof(typeTable -> isFilled));

    if (argc < 2){
        fprintf(stderr, "Usage: %s <file_path>\n", argv[0]);
        return EXIT_FAIL;
    }
    if (argc > 2) {
        fputs("Too many arguments! Expected: 2.\n", stderr);
        return EXIT_FAIL;
    }

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
    return EXIT_OK;
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

//phase2
void push(){
    if (creatingFunction) {
        creatingFunction = false;
        return;
    }
    printf("info line %d: pushing scope stack\n", line);
    if (scopeDepth == MAX_DEPTH - 1){
        printf("warning line %d: Scope depth exceed, can't push!\n", line);
        return;
    }
    scopeStack[++scopeDepth] = (TypeTable*) malloc(sizeof(TypeTable));
}

void pop(){
    printf("info line %d: popping scope stack\n", line);
    if (scopeDepth == -1){
        printf("warning line %d: Scope stack is empty, can't pop!\n", line);
        return;
    }
    printf("\nBefore:\n");
    printAllTable();
    freeTypeTable(line, scopeStack[scopeDepth--]);
    printf("\nAfter:\n");
    printAllTable();
}

void pushExp(Category exp) {
    printf("info line %d: pushing exp %s\n", line, categoryToString(exp));
    if (expDepth == MAX_DEPTH - 1) {
        printf("warning line %d: Exp depth exceed, can't push!\n", line);
    }
    expStack[expDepth++] = exp;
}

Category popExp() {
    printf("info line %d: popping exp %s\n", line, categoryToString(expStack[--expDepth]));
    if (expDepth == -1) {
        printf("warning line %d: Exp stack is empty, can't pop!\n", line);
        return 0;
    }
    return expStack[expDepth];
}

void init(Category category) {
    printf("info line %d: initing type, category: %s\n", line, categoryToString(category));
    if (type != NULL){
        printf("warning line %d: type isn't correctly clear! name: %s, category: %s\n", line, type -> name, categoryToString(type -> category));
    }
    type = (Type*) malloc(sizeof(Type));
    type -> category = category;
    if (category == ARRAY) {
        type -> array = (Array*)malloc(sizeof(Array));
    }
}

void initFunction(char* name) {
    printf("info line %d: initing function name: %s\n", line, name);
    if (functionType != NULL){
        printf("warning line %d: function type isn't correctly clear!%s %s\n", line, categoryToString(functionType -> category), functionType-> name);
    }
    functionType = (Type*)malloc(sizeof(Type));
    functionType -> category = FUNCTION;
    functionType -> name = name;
    functionType -> function = (Function*) malloc(sizeof(Function));
    functionType -> function -> paramNum = 0;
    // functionType -> function -> varList = (CategoryList*)malloc(sizeof(CategoryList));
}

void initStruct(char* name){
    printf("info line %d: initing struct, name: %s\n", line, name);
    if (structureType != NULL){
        printf("warning line %d: struct isn't correctly clear! name: %s\n", line, type -> name);
    }
    structureType = (Type*) malloc(sizeof(Type));
    structureType -> name = name;
    structureType -> category = STRUCTURE;
    structureType -> structure = (Structure*) malloc(sizeof(Structure));
}

void initArray(int size){
    printf("info line %d: initing array, name: %s\n", line, type -> name);
    if (type != NULL){
        printf("warning line %d: type isn't correctly clear\n", line);
    }
    Array* array = (Array*)malloc(sizeof(Array));
    array -> base = type;
    array -> size = size;
    type = (Type*)malloc(sizeof(Type));
    type -> name = array -> base -> name;
    type -> category = ARRAY;
    type -> array = array;
}

bool insert() {
    printf("info line %d: inserting type: %s %s\n", line, categoryToString(type -> category), type -> name);
    if (check(type -> name)) {
        printf("Error type 3 at Line %d: variable \"%s\" is redefined in the same scope\n", line, type -> name);
        return false;
    }
    bool success = insertIntoTypeTable(scopeStack[scopeDepth], type, line);
    if (!success) {
        printf("something is wrong");
        return false;
    }
    printAllTable();
    return success;
}

bool insertFunction(){
    printf("info line %d: inserting function: %s()\n", line, functionType -> name);

    if (check(functionType -> name) && get(functionType -> name) -> category == FUNCTION){
        printf("Error type 4 at Line %d: \"%s\" is redefined\n", line, functionType -> name);
        return false;
    }
    bool success = insertIntoTypeTable(scopeStack[scopeDepth], functionType, line);
    if (!success) {
        printf("something is wrong");
    }
    printAllTable();
    return success;
}

bool insertStruct(){
    printf("info line %d: inserting structure, struct %s\n", line, structureType -> name);
    if (check(structureType -> name) && get(structureType -> name) -> category == STRUCTURE) {
        printf("Error type 15 at Line %d: redefine the same structure type", line);
        return false;
    }
    bool success = insertIntoTypeTable(scopeStack[scopeDepth], structureType, line);
    if (!success) {
        printf("something is wrong.\n");
    }
    creatingStruct = false;
    structureType = NULL;
    printAllTable();
    return success;
}

void clear(){
    printf("info line %d: clearing type, %s %s\n", line, categoryToString(type -> category), type -> name);
    // free(type);
    freeType(line, type);
    type = NULL;
}

void setNull() {
    printf("info line %d: setting type to NULL, current: %s %s\n", line, categoryToString(type -> category), type -> name);
    type = NULL;
}

void clearArray() {
    printf("info line %d: clearing array, name: %s\n", line, type -> name);
    while(type -> category == ARRAY){
        type = type -> array -> base;
    }
}

bool recreate() {
    printf("info line %d: recreating type, %s %s\n", line, categoryToString(type -> category), type -> name);
    Type* temp = (Type*)malloc(sizeof(Type));
    if (type -> category == ARRAY) {
        clearArray();
    }
    temp -> category = type -> category;
    if(type -> category == STRUCTURE){
        temp -> structure = type -> structure;
    }
    type = temp;
}

bool check(char* name) {
    printf("info line %d: checking type, name: %s\n", line, name);
    for (int i = scopeDepth; i >= 0; i--) {
        if(contain(scopeStack[i], name)) {
            return true;
        }
    }
    return false;
}

Type* get(char* name) {
    printf("info line %d: getting type, name: %s\n", line, name);
    Type* result = NULL;
    for (int i = scopeDepth; i >= 0; i--) {
        result = getType(scopeStack[i], name);
        if(result != NULL) {
            printf("info line %d: result: %s\n", line, categoryToString(result -> category));
            return result;
        }
    }
    return NULL;
}

void printAllTable() {
    printf("\n------printing type table------\n\n");
    for (int i = 0; i <= scopeDepth; i++){
        printf("Type table: %d\n\n", i);
        printTable(scopeStack[i]);
    }
}

void intOperate(char* op) {
    lvalue = false;
    Category exp1 = popExp(), exp2 = popExp();
    printf("info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    if (exp1 != INT && exp1 != FLOATNUM && exp1 != NUL){
        printf("Error type 7 at Line %d: binary operation on non-number variables\n", line);
        // TODO: Error type 7 at Line 11: unmatching operand
    }
    if (exp2 != INT && exp2 != FLOATNUM && exp2 != NUL){
        printf("Error type 7 at Line %d: binary operation on non-number variables\n", line);
    }
}

void boolOperate(char* op) {
    lvalue = false;
    Category exp1 = popExp(), exp2 = popExp();
    printf("info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    if (exp1 != BOOLEAN && exp1 != 0){
        printf("error line %d: exp 1 type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp1));
    }
    if (exp2 != BOOLEAN && exp2 != 0){
        printf("error line %d: exp 2 type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp2));
    }
}