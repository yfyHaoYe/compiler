%{
    #include <stdio.h>
    #include <stdbool.h>
    #include <string.h>
    #include "lex.yy.c"
    #include "script/tree_node.h"
    #include "script/lex_interface.h"
    #include "script/type_table.c"
    #include "script/arg_list.h"
    #define MAX_DEPTH 100

    // phase1
    int yydebug = 1;
    char* convertToDec(char*);
    int yyerror(const char*);
    TreeNode* createNode(char* type, char* value, int line, int numChildren, ...); 
    TreeNode* convertNull(TreeNode* node) ;
    void printParseTree(TreeNode* node, int level);
    void getOutputPath(const char *input_path, char *output_path, size_t output_path_size);
    char num[50];
    void freeTree(TreeNode* node);
    FILE* code_file;

    //phase2
    TypeTable* scopeStack[MAX_DEPTH];
    int scopeDepth;
    Expression* expStack[MAX_DEPTH];
    int expDepth;
    // type: 在创建任意一个type时都创建在这里，在insert后置NULL
    // TODO: ARRAY处理
    Type* type;
    // functionType: 在创建函数时创建在这里，通过insertFunction插入，随后置NULL
    Type* functionType;
    // 用于在函数内调用其他函数时进行参数检查
    Function* function;


    CategoryList* cateList;
    TypeList* typeList;

    // structureType: 在创建Structure时创建在这里，通过insertStruct插入，随后置NULL
    Type* structureType;
    // 用于在创建带参函数时，在识别到FunDec而非"{"时执行push
    bool declaringFunction;
    // 用于在创建Struct时，在“}”退出时清理Typetable不free type
    bool declaringStruct;
    // 用于在生成Struct时，调整structType名字结构
    bool definingStruct;
    int tCnt = 0;
    int vCnt = 0;
    int labelCnt = 0;

    void pushExp(Category exp, bool lvalue);
    Expression* popExp();

    void init(Category category);
    void initFunction(char* name);
    void initStruct(char* name);
    void initArray();

    void insert();
    void insertFunction();
    void insertStruct();
    void clear();
    void setNull();
    void clearArray();
    void recreate();
    void recreateStruct();
    Category stringToCategory(char* category);

    void handleDec();
    void handleFunction(char* name);

    bool check(char* name);
    Type* get(char* name);

    void freeLastTable();
    void printAllTable();

    Category intOperate(char* op);
    void boolOperate(char* op);
    void translate_Exp(TreeNode*, const char*);
    void translate_Exp_INT(TreeNode*, const char*);
    void translate_Exp_ID(TreeNode*, const char*);
    void translate_Exp_ASSIGN(TreeNode*, const char*);
    void translate_Exp_PLUS(TreeNode*, const char*);
    void translate_Exp_MINUS(TreeNode*, const char*);
    void translate_Exp_cond(TreeNode*, const char*);
    void translate_Exp_Args(TreeNode*, const char*);
    void translate_cond_Exp(TreeNode* Exp, const char* lb_t, const char* lb_f);
    void translate_cond_Exp_EQ(TreeNode* Exp, const char* lb_t, const char* lb_f);
    void translate_cond_Exp_AND(TreeNode* Exp, const char* lb_t, const char* lb_f);
    void translate_cond_Exp_OR(TreeNode* Exp, const char* lb_t, const char* lb_f);
    void translate_Stmt(TreeNode*);
    void translate_Stmt_RETURN(TreeNode*);
    void translate_Stmt_IF(TreeNode*);
    void translate_Stmt_IFELSE(TreeNode* Stmt);
    void translate_Stmt_WHILE(TreeNode*);
    void translate_Args(TreeNode* Args, ListNode** arg_list);
    void translate_Args_COMMA(TreeNode* Args, ListNode** arg_list);
    const char* new_label();
    const char* new_place();

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
        printParseTree($$, 0);
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
    if(definingStruct){
        freeType(structureType);
        definingStruct = false;
    }else{
        clear();
    }
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
    if(definingStruct){
        insertStruct();
        recreateStruct();
    }else{
        insert();
        recreate();
    }
}
| ExtDecList COMMA VarDec{
    $$ = createNode("ExtDecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
    if(definingStruct){
        insertStruct();
        recreateStruct();
    } else{
        insert();
        recreate();
    }
}
;
/* specifier */
Specifier : TYPE {
    $$ = createNode("Specifier", "", $1.line, 1, createNode("TYPE", $1.string, $1.line, 0));
    init(stringToCategory($1.string));
}
| StructDec {
    $$ = createNode("Specifier", "", $1->line, 1, $1);
    declaringStruct = false;
    definingStruct = true;
}
;

StructSpecifier : StructDec LC DefList RC {
    $$ = createNode("StructSpecifier", "", $1 -> line, 5, $1 -> children[0], $1 -> children[1], createNode("LC", "", $2, 0), $3, createNode("RC", "", $4, 0));
    insertStruct();
    structureType = NULL;
}
;
/* declarator */
StructDec : STRUCT ID {
    $$ = createNode("StructDec", "", $1, 2, createNode("STRUCT", "", $1, 0), createNode("ID", $2.string, $2.line, 0));
    initStruct($2.string);
}
;

VarDec : ID {
    $$ = createNode("VarDec", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    if (definingStruct){
        Type* result = get(structureType -> name);
        if(!result -> category == STRUCTURE){
            printf("Error type ? line %d: define structure with non-struct id %s\n", line, type -> name);
        }else{
            structureType -> structure -> typeList = result -> structure -> typeList;
            strcpy(structureType -> structure -> name, structureType -> name);
            strcpy(structureType -> name, $1.string);
        }
    }else{
        strcpy(type -> name, $1.string);
        printf("info line %d: creating VarDec, name: %s\n", line, type -> name);
    }
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
    insertFunction();
    push();
    clear();
    declaringFunction = true;
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
    if (functionType -> function -> varList == NULL){
        cateList = (CategoryList*)malloc(sizeof(CategoryList));
        functionType -> function -> varList = cateList;
    }else{
        cateList -> next = (CategoryList*)malloc(sizeof(CategoryList));
        cateList = cateList -> next;
    }
    cateList -> next = NULL;
    cateList -> category = type -> category;
    functionType -> function -> paramNum++;
    insert();
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
    Category find = popExp() -> category;
    Category expected = functionType -> function -> returnCategory;
    if (find != expected){
        printf("Error type 8 at Line %d: incompatiable return type, except: %s, got: %s\n", line, categoryToString(expected), categoryToString(find));
    }
    printf("info line %d: returning %s\n", $1, categoryToString(find));

}
| IF LP Exp RP Stmt %prec LOWER {
    $$ = createNode("Stmt", "", $1, 5, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    popExp();
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", $1, 7, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5, createNode("ELSE", "", $6, 0), $7);
    popExp();
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", $1, 5, createNode("WHILE", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    popExp();
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
    if (definingStruct){
        freeType(structureType);
        definingStruct = false;
    } else{
        clear();
    }
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
|
DecList COMMA Dec {
    $$ = createNode("DecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
;
Dec : VarDec {
    $$ = createNode("Dec", "", $1->line, 1, $1);
    handleDec();
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    Category exp = popExp() -> category;
    if (exp != NUL && type -> category != exp) {
        printf("Error type 5 at Line %d: unmatching type on both sides of assignment, expected %s, got %s\n", line, categoryToString(type -> category), categoryToString(exp));
    }
    handleDec();
}
;

/* Expression */
Exp : Exp ASSIGN Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    
    Expression* exp1 = popExp();
    Expression* exp2 = popExp();

    if (!exp2 -> lvalue){
        printf("Error type 6 at Line %d: rvalue appears on the left-side of assignment\n", line);
    }
    if (exp1 -> category != exp2 -> category) {
        printf("Error type 5 at Line %d: unmatching type on both sides of assignment\n", line);
    }
    pushExp(exp2 -> category, false);
}
| Exp AND Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("AND", "", $2, 0), $3);
    boolOperate("and");
    pushExp(BOOLEAN, false);
}
| Exp OR Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("OR", "", $2, 0), $3);
    boolOperate("or");
    pushExp(BOOLEAN, false);
}
| Exp LT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LT", "", $2, 0), $3);
    intOperate("less than");
    pushExp(BOOLEAN, false);
}
| Exp LE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LE", "", $2, 0), $3);
    intOperate("less equal");
    pushExp(BOOLEAN, false);
}
| Exp GT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GT", "", $2, 0), $3);
    intOperate("greater than");
    pushExp(BOOLEAN, false);
}
| Exp GE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GE", "", $2, 0), $3);
    intOperate("greater equal");
    pushExp(BOOLEAN, false);
}
| Exp NE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("NE", "", $2, 0),$3);
    intOperate("not equal");
    pushExp(BOOLEAN, false);
}
| Exp EQ Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("EQ", "", $2, 0), $3);
    intOperate("equal");
    pushExp(BOOLEAN, false);
}
| Exp PLUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("PLUS", "", $2, 0), $3);
    pushExp(intOperate("plus"), false);
}
| Exp MINUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MINUS", "", $2, 0),$3);
    pushExp(intOperate("minus"), false);
}
| Exp MUL Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MUL", "", $2, 0), $3);
    pushExp(intOperate("multiply"), false);
}
| Exp DIV Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DIV", "", $2, 0), $3);
    pushExp(intOperate("divided by"), false);
}
| LP Exp RP {
    $$ = createNode("Exp", "", $1, 3, createNode("LP", "", $1, 0), $2, createNode("RP", "", $3, 0));
}
| MINUS Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("MINUS", "", $1, 0), $2);
    Category exp = popExp() -> category;
    printf("info line %d: minus %s \n", line, categoryToString(exp));
    if (exp != INT && exp != FLOATNUM){
        printf("Error type 7 at Line %d: binary operation on non-number variables\n", line);
    }
    pushExp(INT, false);
}
| NOT Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("NOT", "", $1, 0), $2);
    Category exp = popExp() -> category;
    printf("info line %d: not %s \n", line, categoryToString(exp));
    pushExp(BOOLEAN, false);
}
| Exp LB Exp RB {
    $$ = createNode("Exp", "", $1->line, 4, $1, createNode("LB", "", $2, 0), $3, createNode("RB", "", $4, 0));
    Category exp1 = popExp() -> category, exp2 = popExp() -> category;
    if (exp1 != INT){
        printf("Error type 12 at Line %d: indexing by non-integer", line);
    }
    if (exp2 != ARRAY){
        printf("Error type 10 at line %d: indexing on non-array variable\n", line);
    }
    if (type -> category == ARRAY){
        type = type -> array -> base;
        // if (type -> category == STRUCTURE){
        //     structureType = type;
        // }
    }
    pushExp(type -> category, true);
}
| Exp DOT ID {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DOT", "", $2, 0), createNode("ID", $3.string, $3.line, 0));
    Category exp = popExp() -> category;
    if (exp != STRUCTURE){
        printf("Error type 13 at Line %d: accessing with non-struct variable\n", line);
        pushExp(NUL, true);
    }else{
        if (structureType == NULL){
            printf("something is wrong\n");
        }
        Category category = structureFind(structureType -> structure -> typeList, $3.string);
        if(category == NUL){
            printf("Error type 14 at Line %d: accessing an undefined structure member\n", line);
        }
        pushExp(category, true);
    }
}
| ID {
    $$ = createNode("Exp", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    Type* result = get($1.string);
    if (result != NULL){
        if (result -> category == NUL) {
            printf("warning line %d: type had been used without definition before, name: %s\n", line, $1.string);
            pushExp(NUL, true);
        } else if (result -> category == ARRAY) {       
            type = result;
            pushExp(result -> category, true);
        } else if (result -> category == FUNCTION){
            printf("Error type ? at line %d: function invoked without ()\n", line);
            pushExp(result -> function -> returnCategory, true);
        } else if (result -> category == STRUCTURE){
            structureType = result;
            pushExp(result -> category, true);
        } else {
            pushExp(result -> category, true);
        }
    } else {
        // error: can't find id
        printf("Error type 1 at Line %d: \"%s\" is used without a definition\n", line, $1.string);
        Type* temp = (Type*)malloc(sizeof(TYPE));
        strcpy(temp -> name, $1.string);
        temp -> category = NUL;
        temp -> structure = NULL;
        insertIntoTypeTable(scopeStack[scopeDepth], temp);
        printAllTable();
        pushExp(NUL, true);
    }
}
| INT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("INT", $1.string, $1.line, 0));
    pushExp(INT, false);
}
| FLOAT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("FLOAT", $1.string, $1.line, 0));
    pushExp(FLOATNUM, false);
}
| CHAR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("CHAR", $1.string, $1.line, 0));
    pushExp(CHAR, false);
}
| STR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("STR", $1.string, $1.line, 0));
    pushExp(STRING, false);
}
| ID LP RP {
    $$ = createNode("Exp", "", $1.line, 3, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $1.line, 0), createNode("RP", "", $1.line, 0));
    Type* functionType2 = get($1.string);
    if (functionType2 == NULL){
        printf("Error type 2 at Line %d: \"%s\" is invoked without a definition", line, $1.string);
        pushExp(NUL, false);
    }else if (functionType2 -> category != FUNCTION) {
        printf("Error type 11 at Line %d: invoking non-function variable", line);
        pushExp(functionType2 -> category, false);
    }else {
        if (functionType2 -> function -> paramNum != 0){
            printf("Error type 9 at Line %d: invalid argument number, except %d, got 0\n", line, functionType -> function -> paramNum);
            pushExp(functionType2 -> function -> returnCategory, false);
        }else {
            pushExp(functionType2 -> function -> returnCategory, false);
        }
        if (functionType2 -> function -> returnCategory == STRUCTURE){
            // structureType = NONONO!;
        }
    } 
    
}
| ID LP Args RP {
    $$ = createNode("Exp", "", $1.line, 4, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $2, 0));
    handleFunction($1.string);
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
    last -> category = popExp() -> category;
    last -> next = function -> varList;
    function -> varList = last;
    function -> paramNum++;
}
| Exp {
    $$ = createNode("Args", "", $1->line, 1, $1);
    function = (Function*)malloc(sizeof(Function*));
    function -> paramNum = 1;
    function -> varList = (CategoryList*) malloc(sizeof(CategoryList));
    function -> varList -> category = popExp() -> category;
    function -> varList -> next = NULL;
    function -> returnCategory = NUL;
}
;
INT: DECINT{$$.string = strdup($1.string); $$.line = $1.line;}
| HEXINT {$$.string = strdup(convertToDec($1.string)); $$.line = $1.line;}
;
CHAR: PCHAR {$$.string = strdup($1.string); $$.line = $1.line;}
| HEXCHAR {$$.string = strdup($1.string); $$.line = $1.line;}
;

%%
//modified: translation function
void translate_Exp(TreeNode* Exp, const char* place){
    if(strcmp(Exp->children[0]->type, "INT") == 0){
        translate_Exp_INT(Exp->children[0], place);
    }else if(Exp->numChildren == 1 && strcmp(Exp->children[0]->type, "ID")){
        translate_Exp_ID(Exp->children[0], place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "ASSIGN") == 0){
        translate_Exp_ASSIGN(Exp, place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "PLUS") == 0){
        translate_Exp_PLUS(Exp, place);
    }else if(Exp->numChildren == 2 && strcmp(Exp->children[0]->type, "MINUS") == 0){
        translate_Exp_MINUS(Exp, place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[0]->value, "read") == 0){
        fprintf(code_file, "READ %s\n", place);
    }else if(Exp->numChildren == 4 && strcmp(Exp->children[0]->value, "write") == 0){
        const char* tp = new_place();
        translate_Exp(Exp->children[2], tp);
        fprintf(code_file, "WRITE %s\n", tp);
    }else if(Exp->numChildren == 4 && strcmp(Exp->children[2]->type, "Args") == 0){
        translate_Exp_Args(Exp, place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[0]->type, "LP") == 0){
        translate_Exp(Exp->children[1], place);
    }
}

void translate_Exp_INT(TreeNode* INT, const char* place){
    fprintf(code_file, "%s := #%s\n", place, INT->value);
}

void translate_Exp_ID(TreeNode* ID, const char* place){
    //在type中加上此时的变量名
    const char* var = get(ID->value)->registerName;
    fprintf(code_file, "%s := %s\n", place, var);
}

void translate_Exp_ASSIGN(TreeNode* Exp, const char* place){
    const char* var1 = get(Exp->children[0]->value)->registerName;
    const char* var2 = new_place();
    translate_Exp(Exp->children[2], var2);
    fprintf(code_file, "%s := %s\n", var1, var2);
    fprintf(code_file, "%s := %s\n", place, var1);
}

void translate_Exp_PLUS(TreeNode* Exp, const char* place){
    const char* tp1 = new_place();
    const char* tp2 = new_place();
    translate_Exp(Exp->children[0], tp1);
    translate_Exp(Exp->children[2], tp2);
    fprintf(code_file, "%s := %s + %s", place, tp1, tp2);  
}

void translate_Exp_MINUS(TreeNode* Exp, const char* place){
    const char* tp = new_place();
    translate_Exp(Exp->children[1], tp);
    fprintf(code_file, "%s := #0 - %s", place, tp);
}

void translate_Exp_cond(TreeNode* Exp, const char* place){
    //含条件的表达式
    const char* lb1 = new_label();
    const char* lb2 = new_label();
    fprintf(code_file, "%s := #0\n", place);
    translate_cond_Exp(Exp, lb1, lb2);
    fprintf(code_file, "LABEL %s :\n", lb1);
    fprintf(code_file, "%s := #1\n", place);
    fprintf(code_file, "LABEL %s :\n", lb2);
}

void translate_Exp_Args(TreeNode* Exp, const char* place){
    //TODO: 找对应的function
    ListNode** arg_list = (ListNode**)malloc(sizeof(ListNode*));
    *arg_list = NULL;
    translate_Args(Exp->children[2], arg_list);

}
//TODO：定义语句

//modified: translate condition expression
void translate_cond_Exp(TreeNode* Exp, const char* lb_t, const char* lb_f){
    if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "EQ") == 0){
        translate_cond_Exp_EQ(Exp, lb_t, lb_f);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "AND") == 0){
        translate_cond_Exp_AND(Exp, lb_t, lb_f);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "OR") == 0){
        translate_cond_Exp_OR(Exp, lb_t, lb_f);
    }else if(Exp->numChildren == 2 && strcmp(Exp->children[1]->type, "NOT") == 0){
        translate_cond_Exp(Exp->children[1], lb_f, lb_t);
    }
}

void translate_cond_Exp_EQ(TreeNode* Exp, const char* lb_t, const char* lb_f){
    const char* tp1 = new_place();
    const char* tp2 = new_place();
    translate_Exp(Exp->children[0], tp1);
    translate_Exp(Exp->children[2], tp2);
    fprintf(code_file, "IF %s == %s GOTO %s\n", tp1, tp2, lb_t);
    fprintf(code_file, "GOTO %s\n", lb_f);
}

void translate_cond_Exp_AND(TreeNode* Exp, const char* lb_t, const char* lb_f){
    const char* lb1 = new_label();
    translate_cond_Exp(Exp->children[0], lb1, lb_f);
    fprintf(code_file, "LABEL %s :\n", lb1);
    translate_cond_Exp(Exp->children[2], lb_t, lb_f);
}

void translate_cond_Exp_OR(TreeNode* Exp, const char* lb_t, const char* lb_f){
    const char* lb1 = new_label();
    translate_cond_Exp(Exp->children[0], lb_t, lb1);
    fprintf(code_file, "LABEL %s :\n", lb1);
    translate_cond_Exp(Exp->children[2], lb_t, lb_f);
}

//modified: translate statement
void translate_Stmt(TreeNode* Stmt){
    if(Stmt->numChildren == 3 && strcmp(Stmt->children[0]->type, "RETURN") == 0){
        translate_Stmt_RETURN(Stmt);
    }else if(Stmt->numChildren == 5 && strcmp(Stmt->children[0]->type, "IF") == 0){
        translate_Stmt_IF(Stmt);
    }else if(Stmt->numChildren == 7 && strcmp(Stmt->children[0]->type, "IF") == 0){
        translate_Stmt_IFELSE(Stmt);
    }else if(Stmt->numChildren == 5 && strcmp(Stmt->children[0]->type, "WHILE") == 0){
        translate_Stmt_WHILE(Stmt);
    }
}

void translate_Stmt_RETURN(TreeNode* Stmt){
    const char* tp = new_place();
    translate_Exp(Stmt->children[1], tp);
    fprintf(code_file, "RETURN %s\n", tp);
}

void translate_Stmt_IF(TreeNode* Stmt){
    const char* lb1 = new_label();
    const char* lb2 = new_label();
    translate_cond_Exp(Stmt->children[2], lb1, lb2);
    fprintf(code_file, "LABEL %s :\n", lb1);
    translate_Stmt(Stmt->children[4]);
    fprintf(code_file, "LABEL %s :\n", lb2);
}

void translate_Stmt_IFELSE(TreeNode* Stmt){
    const char* lb1 = new_label();
    const char* lb2 = new_label();
    const char* lb3 = new_label();
    translate_cond_Exp(Stmt->children[2], lb1, lb2);
    fprintf(code_file, "LABEL %s :\n", lb1);
    translate_Stmt(Stmt->children[4]);
    fprintf(code_file, "GOTO %s\n", lb3);
    fprintf(code_file, "LABEL %s :\n", lb2);
    translate_Stmt(Stmt->children[6]);
    fprintf(code_file, "LABEL %s :\n", lb3);
}

void translate_Stmt_WHILE(TreeNode* Stmt){
    const char* lb1 = new_label();
    const char* lb2 = new_label();
    const char* lb3 = new_label();
    fprintf(code_file, "LABEL %s :\n", lb1);
    translate_cond_Exp(Stmt->children[2], lb2, lb3);
    fprintf(code_file, "LABEL %s :\n", lb2);
    translate_Stmt(Stmt->children[4]);
    fprintf(code_file, "GOTO %s\n", lb1);
    fprintf(code_file, "LABEL %s :\n", lb3);
}


//modified: translate Args
void translate_Args(TreeNode* Args, ListNode** arg_list){
    if(Args->numChildren == 3 && strcmp(Args->children[1]->type, "COMMA") == 0){
        translate_Args_COMMA(Args, arg_list);
    }else{
        const char* tp = new_place();
        translate_Exp(Args->children[0], tp);
        insertListNode(arg_list, tp);
    }
}

void translate_Args_COMMA(TreeNode* Args, ListNode** arg_list){
    const char* tp = new_place();
    translate_Exp(Args->children[0], tp);
    insertListNode(arg_list, tp);
    translate_Args(Args, arg_list);
}

const char* new_label(){
    char* label = (char*)malloc(sizeof(char) * 10);
    sprintf(label, "label%d", labelCnt++);
    return label;
}

const char* new_place(){
    char* place = (char*)malloc(sizeof(char) * 10);
    sprintf(place, "t%d", tCnt++);
    return place;
}
// phase1
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
            fprintf(output_file, "  ");
        }
        if(node->numChildren == 0){
            if(strlen(node->value) == 0){
                fprintf(output_file, "%s\n", node->type);
            }else{
                fprintf(output_file, "%s: %s\n", node->type, node->value);
            }
        }
        else {
            fprintf(output_file, "%s (%d)\n", node->type, node->line);
        }
    }

    for (int i = 0; i < node->numChildren; i++) {
        printParseTree(node->children[i], level + 1);
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

//phase2
void push(){
    if (declaringFunction) {
        declaringFunction = false;
        return;
    }
    printf("info line %d: pushing scope stack\n", line);
    if (scopeDepth == MAX_DEPTH - 1){
        printf("warning line %d: Scope depth exceed, can't push!\n", line);
        return;
    }
    scopeStack[++scopeDepth] = (TypeTable*) malloc(sizeof(TypeTable));
    memset(scopeStack[scopeDepth] -> isFilled, 0, sizeof(scopeStack[scopeDepth] -> isFilled));
    memset(scopeStack[scopeDepth] -> buckets, 0, sizeof(scopeStack[scopeDepth] -> buckets));
}

void pop(){
    printf("info line %d: popping scope stack\n", line);
    if (scopeDepth == -1){
        printf("warning line %d: Scope stack is empty, can't pop!\n", line);
        return;
    }
    printf("\nBefore:\n");
    printAllTable();
    if (!declaringStruct){
        freeTypeTable(scopeStack[scopeDepth]);
    }
    scopeDepth--;
    printf("\nAfter:\n");
    printAllTable();
}

void pushExp(Category exp, bool lvalue) {
    printf("info line %d: pushing exp %s\n", line, categoryToString(exp));
    if (expDepth == MAX_DEPTH - 1) {
        printf("warning line %d: Exp depth exceed, can't push!\n", line);
    }
    Expression* expression = (Expression*)malloc(sizeof(Expression));
    expression -> category = exp;
    expression -> lvalue = lvalue; 
    expStack[expDepth++] = expression;
}

Expression* popExp() {
    Expression* expression = expStack[--expDepth];
    printf("info line %d: popping exp %s\n", line, categoryToString(expression -> category));
    if (expDepth == -1) {
        printf("warning line %d: Exp stack is empty, can't pop!\n", line);
        return 0;
    }
    return expression;
}

void init(Category category) {
    printf("info line %d: initing type, category: %s\n", line, categoryToString(category));
    if (type != NULL){
        printf("warning line %d: type isn't correctly clear! name: %s, category: %s\n", line, type -> name, categoryToString(type -> category));
    }
    type = (Type*) malloc(sizeof(Type));
    type -> category = category;
    strcpy(type -> name, "default\0");
    type -> structure = NULL;
    tCnt++;
    sprintf(type -> registerName, "t%d", tCnt++);
    if (category != ARRAY) {
        return;
    }
    printf("warning line %d: initing an array\n", line);
    type -> array = (Array*)malloc(sizeof(Array));
    type -> array -> base = NULL;
    type -> array -> size = 0;    
}

void initFunction(char* name) {
    printf("info line %d: initing function name: %s\n", line, name);
    if (functionType != NULL){
        printf("warning line %d: function type isn't correctly clear! %s %s\n", line, categoryToString(functionType -> category), functionType-> name);
    }
    functionType = (Type*)malloc(sizeof(Type));
    functionType -> category = FUNCTION;
    strcpy(functionType -> name, name);
    functionType -> function = (Function*) malloc(sizeof(Function));
    functionType -> function -> paramNum = 0;
    functionType -> function -> varList = NULL;
    functionType -> function -> returnCategory = type -> category;
}

void initStruct(char* name){
    printf("info line %d: initing struct, name: %s\n", line, name);
    if (structureType != NULL){
        printf("warning line %d: struct isn't correctly clear! name: %s\n", line, type -> name);
    }
    structureType = (Type*) malloc(sizeof(Type));
    strcpy(structureType -> name, name);
    structureType -> category = STRUCTURE;
    structureType -> structure = (Structure*) malloc(sizeof(Structure));
    strcpy(structureType -> structure -> name, "default");
    structureType -> structure -> typeList = NULL;
    declaringStruct = true;
}

void handleDec(){
    if (declaringStruct) {
        if(typeList == NULL){
            typeList = (TypeList*)malloc(sizeof(TypeList));
            structureType -> structure -> typeList = typeList;
        } else {
            typeList -> next = (TypeList*) malloc(sizeof(TypeList));
            typeList = typeList -> next;
        }
        typeList -> next = NULL;
        typeList -> type = type;
    }
    insert();
    recreate();
}

void initArray(int size){
    printf("info line %d: initing array, name: %s\n", line, type -> name);
    Array* array = (Array*)malloc(sizeof(Array));
    array -> base = type;
    array -> size = size;
    type = (Type*)malloc(sizeof(Type));
    strcpy(type -> name, array -> base -> name);
    type -> category = ARRAY;
    type -> array = array;
}

void insert() {
    if (definingStruct) {
        insertStruct();
        return;
    }
    printf("info line %d: inserting type: %s %s\n", line, categoryToString(type -> category), type -> name);
    if (check(type -> name)) {
        Type* t = get(type -> name);
        if (t -> category == NUL) {
            t -> category = type -> category;
            printf("warning line %d, recovering %s used but not declared upon\n", line, type -> name);
            return;
        }
        printf("Error type 3 at Line %d: variable \"%s\" is redefined in the same scope\n", line, type -> name);
        return;
    }
    insertIntoTypeTable(scopeStack[scopeDepth], type);
    printAllTable();
}

void insertFunction(){
    printf("info line %d: inserting function: %s\n", line, functionType -> name);
    if (check(functionType -> name) && get(functionType -> name) -> category == FUNCTION){
        printf("Error type 4 at Line %d: \"%s\" is redefined\n", line, functionType -> name);
        return;
    }
    insertIntoTypeTable(scopeStack[scopeDepth], functionType);
    printAllTable();
}

void insertStruct(){
    printf("info line %d: inserting structure, struct %s %s\n", line, structureType -> structure -> name, structureType -> name);
    if (check(structureType -> name) && get(structureType -> name) -> category == STRUCTURE) {
        printf("Error type 15 at Line %d: redefine the same structure type\n", line);
        return;
    }
    insertIntoTypeTable(scopeStack[scopeDepth], structureType);
    printAllTable();
    declaringStruct = false;
}

void clear(){
    printf("info line %d: clearing type, %s %s\n", line, categoryToString(type -> category), type -> name);
    freeType(type);
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

void recreate() {
    if (definingStruct) {
        recreateStruct();
        return;
    }
    printf("info line %d: recreating type, %s %s\n", line, categoryToString(type -> category), type -> name);
    if (type -> category == ARRAY) {
        clearArray();
    }
    if(type -> category == STRUCTURE){
        printf("warning line %d: recreating and the type is a structure\n", line);
    }
    Type* temp = (Type*)malloc(sizeof(Type));
    temp -> category = type -> category;
    strcpy(temp -> name, "default\0");
    type -> structure = NULL;
    type = temp;
}

void recreateStruct() {
    printf("info line %d: recreating struct, %s %s\n", line, structureType -> structure -> name, structureType -> name);
    if(structureType -> category != STRUCTURE){
        printf("warning line %d: recreating struct but structure type not a structure\n", line);
    }
    Type* temp = (Type*)malloc(sizeof(Type));
    temp -> category = STRUCTURE;
    strcpy(temp -> name, "default\0");
    temp -> structure = structureType -> structure;
    structureType = temp;
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
        printf("\n");
    }
}

Category intOperate(char* op) {
    Category exp1 = popExp() -> category, exp2 = popExp() -> category;
    printf("info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    if (exp1 != INT && exp1 != FLOATNUM){
        printf("Error type 7 at Line %d: binary operation on non-number variables\n", line);
    }
    if (exp2 != INT && exp2 != FLOATNUM){
        printf("Error type 7 at Line %d: binary operation on non-number variables\n", line);
    }
    if (exp1 == INT && exp2 == FLOATNUM || exp1 == FLOATNUM && exp2 == INT) {
        printf("Error type 7 at Line %d: unmatching operands\n", line);
    }
    if (exp1 == INT && exp2 == INT || exp1 == FLOAT && exp2 == FLOAT) {
        return exp1;
    }
    return NUL;
}

void boolOperate(char* op) {
    Category exp1 = popExp() -> category, exp2 = popExp() -> category;
    printf("info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    pushExp(BOOLEAN, false);
}

void handleFunction(char* name){
    int paramNum1 = function -> paramNum;
    CategoryList* varList1 = function -> varList;
    Type* functionType2 = get(name);
    if (functionType2 == NULL) {
        printf("Error type 2 at Line %d: \"%s\" is invoked without a definition\n", line, name);
        pushExp(NUL, false);
        return;
    }
    if (functionType2 -> category != FUNCTION) {
        printf("Error type 11 at Line %d: invoking non-function variable\n", line);
        pushExp(NUL, false);
        return;
    }
    int paramNum2 = functionType2 -> function -> paramNum;
    CategoryList* varList2 = functionType2 -> function -> varList;
    if (paramNum1 != paramNum2) {
        printf("Error type 9 at Line %d: invalid argument number, except %d, got %d\n", line, paramNum2, paramNum1);
        return;
    }
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

    if (varList1 != NULL){
        printf("warning line %d: paramnum is same, but varlist 1 longer\n", line);
    } 
    if (varList2 != NULL) {
        printf("warning line %d: paramnum is same, but varlist 2 longer\n", line);
    }
    pushExp(functionType -> function -> returnCategory, false);
    freeFunction(function);
    function = NULL;
    functionType2 = NULL;
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
    code_file = fopen("code.txt", "w");
    if(!(yyin = fopen(file_path, "r"))){
        perror(argv[1]);
        return EXIT_FAIL;
    }

    init(INT);
    initFunction("read");
    insertFunction();
    clear();
    functionType = NULL;

    init(NUL);
    initFunction("write");
    functionType -> function -> paramNum = 1;
    functionType -> function -> varList = (CategoryList*)malloc(sizeof(CategoryList));
    functionType -> function -> varList -> category = INT;
    functionType -> function -> varList -> next = NULL;
    insertFunction();
    clear();
    functionType = NULL;

    yyparse();
    fclose(output_file);
    return EXIT_OK;
}