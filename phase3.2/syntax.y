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
    int yyerror(char*);
    TreeNode* createNode(char* type, char* value, int line, int numChildren, ...); 
    TreeNode* convertNull(TreeNode* node) ;
    void printParseTree(TreeNode* node, int level);
    void getOutputPath(char *input_path, char *output_path, size_t output_path_size);
    char num[50];
    void freeTree(TreeNode* node);
    FILE* code_file;
    FILE* debug_file;

    //phase2
    TypeTable* scopeStack[MAX_DEPTH];
    int scopeDepth;
    Expression* expStack[MAX_DEPTH];
    int expDepth;

    Type* arrayType;
    Category category;
    Function* functionCreate;
    Function* functionInvoke;
    Structure* structureDef;
    Structure* structureDec;

    // 用于创建带参函数时生成参数列表
    CategoryList* cateList;
    // 用于创建结构体时生成type列表
    TypeList* typeList;

    // 用于创建带参函数时，在识别到FunDec而非"{"时执行push
    bool declaringFunction;
    // 用于创建structure定义时，插入每个type后同时添加到typelist中
    bool definingStruct;

    void pushExp(bool lvalue, Category exp, Type* type);
    Expression* popExp();

    void initInsert(char* name);
    void initFunction(char* name);
    void initStruct(char* name);
    void initArray();
    void insert();
    void clearArray();

    Category intOperate(char* op);
    void boolOperate(char* op);

    void handleParam();
    void handleID(char* name);
    void handleFunction(char* name);
    void handleExpArray();
    void handleExpFetchStructure(char* name);
    void handleReturn();

    bool check(char* name);
    Type* get(char* name);

    void printAllTable();

    // phase3
    int tCnt = 0;
    int vCnt = 0;
    int labelCnt = 0;

    char* codeStack[100];
    int codeDepth = 0;
    
    void pushCode(char* code);
    char* popCode();

    char* translate_Exp(TreeNode*, char*);
    char* translate_Exp_INT(TreeNode*, char*);
    char* translate_Exp_ID(TreeNode*, char*);
    char* translate_Exp_ASSIGN(TreeNode*, char*);
    char* translate_Exp_NUM_OP(TreeNode*, char*, char*);
    char* translate_Exp_MINUS(TreeNode*, char*);
    char* translate_Exp_Args(TreeNode*, char*);
    char* translate_Exp_Func(TreeNode* Exp, char* place);
    char* translate_cond_Exp(TreeNode* Exp, char* lb_t, char* lb_f);
    char* translate_cond_Exp_BOOL_OP(TreeNode* Exp, char* lb_t, char* lb_f, char* op);
    char* translate_cond_Exp_AND(TreeNode* Exp, char* lb_t, char* lb_f);
    char* translate_cond_Exp_OR(TreeNode* Exp, char* lb_t, char* lb_f);
    void translate_Stmt(TreeNode*);
    void translate_Stmt_RETURN(TreeNode*);
    void translate_Stmt_IF(TreeNode*);
    void translate_Stmt_IFELSE(TreeNode* Stmt);
    void translate_Stmt_WHILE(TreeNode*);
    char* translate_Args(TreeNode* Args, ListNode** arg_list);
    char* translate_Param_Dec(TreeNode* Param);
    char* new_label();
    char* new_place(char kind);
    void translate_StmtList(TreeNode* StmtList);

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
%type<node> Program ExtDefList ExtDef ExtDecList Specifier StructSpecifier VarDec FunDec VarList ParamDec CompSt StmtList Stmt DefList Def DecList Dec Exp Args ErrorStmt FunID StructDec Array
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
    category = NUL;
}
| StructSpecifier SEMI {
    $$ = createNode("ExtDef", "", $1->line, 2, $1, createNode("SEMI", "", $2, 0));
}
| Specifier FunDec CompSt {
    $$ = createNode("ExtDef", "", $1->line, 3, $1, $2, $3);
    fprintf(syntax_file, "info line %d: function end\n", line);
    fputs(popCode(), code_file);
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
| ExtDecList COMMA VarDec{
    $$ = createNode("ExtDecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
;
/* specifier */
Specifier : TYPE {
    $$ = createNode("Specifier", "", $1.line, 1, createNode("TYPE", $1.string, $1.line, 0));
    category = stringToCategory($1.string);
}
| STRUCT ID {
    $$ = createNode("StructDec", "", $1, 2, createNode("STRUCT", "", $1, 0), createNode("ID", $2.string, $2.line, 0));
    Type* result = get($2.string);
    category = STRUCTURE;
    if (result == NULL || result -> category != STRUCTURE){
        fprintf(syntax_file, "Error Type 2 at  line %d: structure %s not defined!\n", line, $2.string);
    }else {
        structureDec = result -> structure;
    }
}
;

StructSpecifier : StructDec LC DefList RC {
    $$ = createNode("StructSpecifier", "", $1 -> line, 5, $1 -> children[0], $1 -> children[1], createNode("LC", "", $2, 0), $3, createNode("RC", "", $4, 0));
    definingStruct = false;
    structureDef = NULL;
    typeList = NULL;
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
    fprintf(syntax_file, "info line %d: creating VarDec from ID, name: %s\n", line, $1.string);
    initInsert($1.string);
}
| Array {
    $$ = $1;
    fprintf(syntax_file, "info line %d: creating VarDec from Array, name: %s\n", line, arrayType -> name);
    insert(arrayType);
    clearArray();
}
;

Array: Array LB INT RB {
    $$ = createNode("VarDec", "", $1->line, 4, $1, createNode("LB", "", $2, 0), createNode("INT", $3.string, $3.line, 0), createNode("RB", "", $4, 0));
    initArray(arrayType -> name, atoi($3.string), arrayType); 
}
| ID LB INT RB {
    $$ = createNode("VarDec", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    Type* base = (Type*)malloc(sizeof(Type));
    strcpy(base->name,  $1.string);
    base -> category = category;
    base -> array = NULL;
    initArray($1.string, atoi($3.string), base);
}
| Array LB INT error {
    yyerror(" Missing closing square bracket ']'");
}
| ID LB INT error {
    yyerror(" Missing closing square bracket ']'");
}
;

FunDec : FunID LP VarList RP {
    $$ = createNode("FunDec", "", $1->line, 4, $1, createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0));
    cateList = NULL;
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
FunID : ID {
    $$ = createNode("ID", $1.string, $1.line, 0);
    initFunction($1.string);
    if (strcmp($1.string, "write") != 0 && strcmp($1.string, "read") != 0){
        fprintf(code_file, "FUNCTION %s :\n", $1.string);
    }
}
;
VarList : ParamDec COMMA VarList {
    $$ = createNode("VarList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
}
| ParamDec {
    $$ = createNode("VarList", "", $1->line, 1, $1);
}
;
ParamDec : Specifier VarDec {
    // TODO PHASE2: function args struct
    $$ = createNode("ParamDec", "", $1->line, 2, $1, $2);
    handleParam();
    char* code = translate_Param_Dec($2);
    fputs(code, code_file);
}
;
/* statement */
CompSt : LC DefList StmtList RC {
    $$ = createNode("CompSt", "", $1, 4, createNode("LC", "", $1, 0), $2, $3, createNode("RC", "", $4, 0));
}
;
StmtList : Stmt StmtList {
    $$ = createNode("StmtList", "", $1->line, 2, $1, $2);
    translate_StmtList($$);
}
|  {
    $$ = createNode("StmtList", "", 0, 0);
    $$->empty = true;
    pushCode("");
}
;
Stmt : Exp SEMI {
    $$ = createNode("Stmt", "", $1->line, 2, $1, createNode("SEMI", "", $2, 0));
    popExp();
    translate_Stmt($$);
}
| CompSt {
    $$ = createNode("Stmt", "", $1->line, 1, $1);
}
| RETURN Exp SEMI {
    $$ = createNode("Stmt", "", $1, 3, createNode("RETURN", "", $1, 0), $2, createNode("SEMI", "", $3, 0));
    handleReturn();
    translate_Stmt($$);
}
| IF LP Exp RP Stmt %prec LOWER {
    $$ = createNode("Stmt", "", $1, 5, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    popExp();
    translate_Stmt($$);
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", $1, 7, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5, createNode("ELSE", "", $6, 0), $7);
    popExp();
    translate_Stmt($$);
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", $1, 5, createNode("WHILE", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    popExp();
    translate_Stmt($$);
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
    structureDec = NULL;
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
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    Category exp = popExp() -> category;
    if (exp != NUL && category != exp) {
        fprintf(syntax_file, "Error type 5 at Line %d: unmatching type on both sides of assignment, expected %s, got %s\n", line, categoryToString(category), categoryToString(exp));
    }
    Type* cur = get($1->children[0]->value);
    fputs(translate_Exp($3, cur->registerName), code_file);
}
;

/* Expression */
Exp : Exp ASSIGN Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    Expression* exp1 = popExp();
    Expression* exp2 = popExp();

    if (!exp2 -> lvalue){
        fprintf(syntax_file, "Error type 6 at Line %d: rvalue appears on the left-side of assignment\n", line);
    }
    if (exp1 -> category != exp2 -> category) {
        fprintf(syntax_file, "Error type 5 at Line %d: unmatching type on both sides of assignment\n", line);
    }
    pushExp(false, exp2 -> category, NULL);
}
| Exp AND Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("AND", "", $2, 0), $3);
    boolOperate("and");
    pushExp(false, BOOLEAN, NULL);
}
| Exp OR Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("OR", "", $2, 0), $3);
    boolOperate("or");
    pushExp(false, BOOLEAN, NULL);
}
| Exp LT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LT", "", $2, 0), $3);
    intOperate("less than");
    pushExp(false, BOOLEAN, NULL);
}
| Exp LE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("LE", "", $2, 0), $3);
    intOperate("less equal");
    pushExp(false, BOOLEAN, NULL);
}
| Exp GT Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GT", "", $2, 0), $3);
    intOperate("greater than");
    pushExp(false, BOOLEAN, NULL);
}
| Exp GE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("GE", "", $2, 0), $3);
    intOperate("greater equal");
    pushExp(false, BOOLEAN, NULL);
}
| Exp NE Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("NE", "", $2, 0),$3);
    intOperate("not equal");
    pushExp(false, BOOLEAN, NULL);
}
| Exp EQ Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("EQ", "", $2, 0), $3);
    intOperate("equal");
    pushExp(false, BOOLEAN, NULL);
}
| Exp PLUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("PLUS", "", $2, 0), $3);
    pushExp(false, intOperate("plus"), NULL);
}
| Exp MINUS Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MINUS", "", $2, 0),$3);
    pushExp(false, intOperate("minus"), NULL);
}
| Exp MUL Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("MUL", "", $2, 0), $3);
    pushExp(false, intOperate("multiply"), NULL);
}
| Exp DIV Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DIV", "", $2, 0), $3);
    pushExp(false, intOperate("divided by"), NULL);
}
| LP Exp RP {
    $$ = createNode("Exp", "", $1, 3, createNode("LP", "", $1, 0), $2, createNode("RP", "", $3, 0));
}
| MINUS Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("MINUS", "", $1, 0), $2);
    Category exp = popExp() -> category;
    fprintf(syntax_file, "info line %d: minus %s \n", line, categoryToString(exp));
    if (exp != INT && exp != FLOATNUM){
        fprintf(syntax_file, "Error type 7 at Line %d: binary operation on non-number variables\n", line);
    }
    pushExp(false, INT, NULL);
}
| NOT Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("NOT", "", $1, 0), $2);
    Category exp = popExp() -> category;
    fprintf(syntax_file, "info line %d: not %s \n", line, categoryToString(exp));
    pushExp(false, BOOLEAN, NULL);
}
| Exp LB Exp RB {
    $$ = createNode("Exp", "", $1->line, 4, $1, createNode("LB", "", $2, 0), $3, createNode("RB", "", $4, 0));
    handleExpArray();
}
| Exp DOT ID {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DOT", "", $2, 0), createNode("ID", $3.string, $3.line, 0));
    handleExpFetchStructure($3.string);
}
| ID {
    $$ = createNode("Exp", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    handleID($1.string);
}
| INT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("INT", $1.string, $1.line, 0));
    pushExp(false, INT, NULL);
}
| FLOAT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("FLOAT", $1.string, $1.line, 0));
    pushExp(false, FLOATNUM, NULL);
}
| CHAR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("CHAR", $1.string, $1.line, 0));
    pushExp(false, CHAR, NULL);
}
| STR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("STR", $1.string, $1.line, 0));
    pushExp(false, STRING, NULL);
}
| ID LP RP {
    $$ = createNode("Exp", "", $1.line, 3, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $1.line, 0), createNode("RP", "", $1.line, 0));
    if (strcpy($1.string,"read") != 0){
        handleFunction($1.string);
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
    last -> next = functionInvoke -> varList;
    functionInvoke -> varList = last;
    functionInvoke -> paramNum++;
    
}
| Exp {
    $$ = createNode("Args", "", $1->line, 1, $1);
    functionInvoke = (Function*)malloc(sizeof(Function));
    functionInvoke -> paramNum = 1;
    functionInvoke -> varList = (CategoryList*) malloc(sizeof(CategoryList));
    functionInvoke -> varList -> category = popExp() -> category;
    functionInvoke -> varList -> next = NULL;
    functionInvoke -> returnCategory = NUL;
}
;
INT: DECINT{$$.string = strdup($1.string); $$.line = $1.line;}
| HEXINT {$$.string = strdup(convertToDec($1.string)); $$.line = $1.line;}
;
CHAR: PCHAR {$$.string = strdup($1.string); $$.line = $1.line;}
| HEXCHAR {$$.string = strdup($1.string); $$.line = $1.line;}
;

%%

void pushCode(char* code) {
   //printf("line %d pushing!\n%s\n", line, code);
    if (codeDepth == 100) {
       //printf("code stack is full!\n");
        return;
    }
    codeStack[codeDepth++] = code;
}
char* popCode() {
    if (codeDepth == 0) {
       //printf("code stack is empty!\n");
        return "hello world\n";
    }
    --codeDepth;
   //printf("line %d popping!\n%s\n", line, codeStack[codeDepth]);
    return codeStack[codeDepth];
}

//modified: translation function
// OK
char* translate_Exp(TreeNode* Exp, char* place){
    if(strcmp(Exp->children[0]->type, "INT") == 0){
        // INT
        return translate_Exp_INT(Exp->children[0], place);
    }else if(Exp->numChildren == 1 && strcmp(Exp->children[0]->type, "ID") == 0){
        // ID
        return translate_Exp_ID(Exp->children[0], place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "ASSIGN") == 0){
        // Exp ASSIGN Exp
        return translate_Exp_ASSIGN(Exp, place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "PLUS") == 0){
        // Exp PLUS Exp
        return translate_Exp_NUM_OP(Exp, place, "+");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "MINUS") == 0){
        // Exp MINUS Exp
        return translate_Exp_NUM_OP(Exp, place, "-");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "MUL") == 0){
        // Exp MUL Exp
        return translate_Exp_NUM_OP(Exp, place, "*");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "DIV") == 0){
        // Exp DIV Exp
        return translate_Exp_NUM_OP(Exp, place, "/");
    }else if(Exp->numChildren == 2 && strcmp(Exp->children[0]->type, "MINUS") == 0){
        // MINUS Exp
        return translate_Exp_MINUS(Exp, place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[0]->value, "read") == 0){
        // read ( )
        char* code = (char*)calloc(30, sizeof(char));
        sprintf(code, "READ %s\n", place);
        return code;
    }else if(Exp->numChildren == 4 && strcmp(Exp->children[0]->value, "write") == 0){
        // write ( Exp )
        char* code = (char*)calloc(300, sizeof(char));
        char* code1 = translate_Exp(Exp -> children[2] -> children[0], place);
        sprintf(code, "%sWRITE %s\n", code1, place);
        return code;
    }else if(Exp->numChildren == 4 && strcmp(Exp->children[2]->type, "Args") == 0){
        // ID ( Args ) invoking
        return translate_Exp_Args(Exp, place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[0]->type, "LP") == 0){
        // ( Exp )
        return translate_Exp(Exp->children[1], place);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "LP") == 0){
        //  ID ( )
        return translate_Exp_Func(Exp, place);
    }
}
// OK
char* translate_Exp_INT(TreeNode* INT, char* place){
    char* code = (char*)malloc(20);
    sprintf(code, "%s := #%s\n", place, INT->value);
        return code;
}

// OK
char* translate_Exp_ID(TreeNode* ID, char* place){
    char* code = (char*)malloc(20);
    char* var = get(ID->value)->registerName;
    sprintf(code, "%s := %s\n", place, var);
    return code;
}

// OK
char* translate_Exp_ASSIGN(TreeNode* Exp, char* place){
    char* var1 = get(Exp->children[0]->children[0]->value)->registerName;
    char* var2 = new_place('t');

    char* code1 = translate_Exp(Exp -> children[2], var2);
    char* code2 = (char*)calloc(30, 1); sprintf(code2, "%s := %s\n", var1, var2);
    char* code3 = (char*)calloc(30, 1); sprintf(code3, "%s := %s\n", place, var1);

    char* code = (char*) calloc(strlen(code1)+60, 1);
    sprintf(code, "%s%s%s", code1, code2, code3);
    free(code1);
    free(code2);
    free(code3);
    return code;
}

// OK
char* translate_Exp_NUM_OP(TreeNode* Exp, char* place, char* op){
    char* tp1 = new_place('t');
    char* tp2 = new_place('t');
    
    char* code1 = translate_Exp(Exp->children[0], tp1);
    char* code2 = translate_Exp(Exp->children[2], tp2);
    char* code3 = (char*)calloc(30, 1); sprintf(code3, "%s := %s %s %s\n", place, tp1, op, tp2); 
     
    char* code = (char*)calloc(strlen(code1) + strlen(code2) + 30, 1);
    sprintf(code, "%s%s%s", code1, code2, code3);
    free(code1);
    free(code2);
    free(code3);
    return code;
}
// OK
char* translate_Exp_MINUS(TreeNode* Exp, char* place){
    char* tp = new_place('t');
    char* code1 = translate_Exp(Exp->children[1], tp);
    char* code2 = (char*)calloc(30,1); sprintf(code2, "%s := #0 - %s\n", place, tp);
    char* code = (char*)calloc(strlen(code1) + 30, 1);
    sprintf(code, "%s%s", code1, code2);
    free(code1);
    free(code2);
    return code;
}

// OK
char* translate_Exp_Args(TreeNode* Exp, char* place){
    
    ListNode** arg_list = (ListNode**)malloc(sizeof(ListNode*));
    *arg_list = NULL;
    char* code1 = translate_Args(Exp->children[2], arg_list);
    ListNode* current = *arg_list;
    
    char* code = (char*)calloc(500, 1);
    // strcpy(code, code1);
    sprintf(code, "%s", code1);
    char* arg = (char*)calloc(30, 1);
    int cnt = 0;
    while(current != NULL){
        sprintf(arg, "ARG %s\n", current->arg);
        strcat(code, arg);
        current = current -> next;
    };
    char* name = Exp -> children[0] -> value;

    char* call = (char*)calloc(300, 1);
    sprintf(call, "%s := CALL %s\n", place, name);

    strcat(code, call);
    free(code1);
    free(arg);
    free(call);
    return code;
}

// OK
char* translate_Exp_Func(TreeNode* Exp, char* place){
    char* name = Exp -> children[0] -> value;
    char* code = (char*)calloc(30, 1);
    sprintf(code, "%s := CALL %s\n", place, name);
    return code;
}

//modified: translate condition expression
// OK
char* translate_cond_Exp(TreeNode* Exp, char* lb_t, char* lb_f){
    if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "EQ") == 0){
        // Exp == Exp
        return translate_cond_Exp_BOOL_OP(Exp, lb_t, lb_f, "==");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "NE") == 0){
        // Exp != Exp
        return translate_cond_Exp_BOOL_OP(Exp, lb_t, lb_f, "!=");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "GE") == 0){
        // Exp >= Exp
        return translate_cond_Exp_BOOL_OP(Exp, lb_t, lb_f, ">=");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "GT") == 0){
        // Exp > Exp
        return translate_cond_Exp_BOOL_OP(Exp, lb_t, lb_f, ">");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "LE") == 0){
        // Exp <= Exp
        return translate_cond_Exp_BOOL_OP(Exp, lb_t, lb_f, "<=");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "LT") == 0){
        // Exp < Exp
        return translate_cond_Exp_BOOL_OP(Exp, lb_t, lb_f, "<");
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "AND") == 0){
        // Exp && Exp
        return translate_cond_Exp_AND(Exp, lb_t, lb_f);
    }else if(Exp->numChildren == 3 && strcmp(Exp->children[1]->type, "OR") == 0){
        // Exp || Exp
        return translate_cond_Exp_OR(Exp, lb_t, lb_f);
    }else if(Exp->numChildren == 2 && strcmp(Exp->children[1]->type, "NOT") == 0){
        // ! Exp
        return translate_cond_Exp(Exp->children[1], lb_f, lb_t);
    }
}

// OK
char* translate_cond_Exp_BOOL_OP(TreeNode* Exp, char* lb_t, char* lb_f, char* op){
    char* tp1 = new_place('t');
    char* tp2 = new_place('t');
    
    char* code1 = translate_Exp(Exp->children[0], tp1);
    char* code2 = translate_Exp(Exp->children[2], tp2);
    char* code3 = (char*)calloc(30, 1); sprintf(code3, "IF %s %s %s GOTO %s\n", tp1, op, tp2, lb_t);
    char* code4 = (char*)calloc(30, 1); sprintf(code4, "GOTO %s\n", lb_f);
    
    char* code = (char*)calloc(strlen(code1) + strlen(code2) + 60, 1);
    sprintf(code, "%s%s%s%s", code1, code2, code3, code4);
    free(code1);
    free(code2);
    free(code3);
    free(code4);
    return code;
}

// OK
char* translate_cond_Exp_AND(TreeNode* Exp, char* lb_t, char* lb_f){
    char* lb1 = new_label();
    
    char* code1 = translate_cond_Exp(Exp->children[0], lb1, lb_f);
    char* code2 = (char*)calloc(30, 1); sprintf(code2, "LABEL %s :\n", lb1);
    char* code3 = translate_cond_Exp(Exp->children[2], lb_t, lb_f);

    char* code = (char*)calloc(strlen(code1)+strlen(code3)+30, 1);
    sprintf(code, "%s%s%s", code1, code2, code3);
    free(code1);
    free(code2);
    free(code3);
    return code;
}

// OK
char* translate_cond_Exp_OR(TreeNode* Exp, char* lb_t, char* lb_f){
    char* lb1 = new_label();
    
    char* code1 = translate_cond_Exp(Exp->children[0], lb_t, lb1);
    char* code2 = (char*)calloc(30, 1); sprintf(code2, "LABEL %s :\n", lb1);
    char* code3 = translate_cond_Exp(Exp->children[2], lb_t, lb_f);

    char* code = (char*)calloc(strlen(code1)+strlen(code3)+30, 1);
    sprintf(code, "%s%s%s", code1, code2, code3);
    free(code1);
    free(code2);
    free(code3);
    return code;
}

//modified: translate statement
// OK
void translate_Stmt(TreeNode* Stmt){
    if(Stmt->numChildren == 3 && strcmp(Stmt->children[0]->type, "RETURN") == 0){
        translate_Stmt_RETURN(Stmt);
    }else if(Stmt->numChildren == 5 && strcmp(Stmt->children[0]->type, "IF") == 0){
        translate_Stmt_IF(Stmt);
    }else if(Stmt->numChildren == 7 && strcmp(Stmt->children[0]->type, "IF") == 0){
        translate_Stmt_IFELSE(Stmt);
    }else if(Stmt->numChildren == 5 && strcmp(Stmt->children[0]->type, "WHILE") == 0){
        translate_Stmt_WHILE(Stmt);
    }else if(Stmt->numChildren == 2 && strcmp(Stmt->children[1]->type, "SEMI") == 0){
        char* code = translate_Exp(Stmt -> children[0], new_place('t'));
        pushCode(code);
    }
}

void translate_StmtList(TreeNode* StmtList){
    char* code2 = popCode();
    char* code1 = popCode();
    char* code = (char*)calloc(strlen(code1)+strlen(code2)+1, 1);
    sprintf(code, "%s%s", code1, code2);
    // free(code1);
    // free(code2);
    pushCode(code);
}

// OK
void translate_Stmt_RETURN(TreeNode* Stmt){
    char* tp = new_place('t');
    
    char* code1 = translate_Exp(Stmt->children[1], tp);
    char* code2 = (char*)calloc(30, 1); sprintf(code2, "RETURN %s\n", tp);

    char* code = (char*)calloc(strlen(code1)+30, 1);
    sprintf(code, "%s%s", code1, code2);
    free(code1);
    free(code2);
    pushCode(code);
}

// OK
void translate_Stmt_IF(TreeNode* Stmt){
    char* lb1 = new_label();
    char* lb2 = new_label();
    
    char* code1 = translate_cond_Exp(Stmt->children[2], lb1, lb2);
    char* code2 = (char*)calloc(30, 1); sprintf(code2, "LABEL %s :\n", lb1);
    char* code3 = popCode();
    char* code4 = (char*)calloc(30, 1); sprintf(code4, "LABEL %s :\n", lb2);
    
    char* code = (char*)calloc(strlen(code1) + strlen(code3) + 60, 1);
    sprintf(code, "%s%s%s%s", code1, code2, code3, code4);
    free(code1);
    free(code2);
    free(code3);
    free(code4);
    pushCode(code);
}

// OK
void translate_Stmt_IFELSE(TreeNode* Stmt){
    char* lb1 = new_label();
    char* lb2 = new_label();
    char* lb3 = new_label();

    char* code1 = translate_cond_Exp(Stmt->children[2], lb1, lb2);
    char* code2 = (char*)calloc(30, 1); sprintf(code2, "LABEL %s :\n", lb1);
    char* code6 = popCode();
    char* code4 = (char*)calloc(30, 1); sprintf(code4, "GOTO %s\n", lb3);
    char* code5 = (char*)calloc(30, 1); sprintf(code5, "LABEL %s :\n", lb2);
    char* code3 = popCode();
    char* code7 = (char*)calloc(30, 1); sprintf(code7, "LABEL %s :\n", lb3);
    char* code = (char*)calloc(strlen(code1) + strlen(code3) + strlen(code6) + 120, 1);
    sprintf(code, "%s%s%s%s%s%s%s", code1, code2, code3, code4, code5, code6, code7);
    free(code1);
    free(code2);
    free(code3);
    free(code4);
    free(code5);
    free(code6);
    free(code7);
    pushCode(code);
}

// OK
void translate_Stmt_WHILE(TreeNode* Stmt){
    char* lb1 = new_label();
    char* lb2 = new_label();
    char* lb3 = new_label();
    
    char* code1 = (char*)calloc(30, 1); sprintf(code1, "LABEL %s :\n", lb1);
    char* code2 = translate_cond_Exp(Stmt->children[2], lb2, lb3);
    char* code3 = (char*)calloc(30, 1); sprintf(code3, "LABEL %s :\n", lb2);
    char* code4 = popCode();
    char* code5 = (char*)calloc(30, 1); sprintf(code5, "GOTO %s\n", lb1);
    char* code6 = (char*)calloc(30, 1); sprintf(code6, "LABEL %s :\n", lb3);
    char* code = (char*)calloc(strlen(code2)+strlen(code4)+60, 1);
    sprintf(code, "%s%s%s%s%s%s", code1, code2, code3, code4, code5, code6);
    free(code1);
    free(code2);
    free(code3);
    free(code4);
    free(code5);
    free(code6);
    pushCode(code);
}


//modified: translate Args
char* translate_Args(TreeNode* Args, ListNode** arg_list){
    char* code = (char*)calloc(300, 1);
    if(Args->numChildren == 3 && strcmp(Args->children[1]->type, "COMMA") == 0){
        strcat(code, translate_Args(Args->children[2], arg_list));
    }
    char* tp = new_place('t');
    insertListNode(arg_list, tp);
    strcat(code, translate_Exp(Args->children[0], tp));
    return code;
}


char* translate_Param_Dec(TreeNode* Param){
    Type* result = get(Param -> children[0] -> value);
    char* code = (char*)calloc(20, 1);
    sprintf(code, "PARAM %s\n", result -> registerName);
    return code;
}

char* new_label(){
    char* label = (char*)calloc(10, 1);
    sprintf(label, "label%d", labelCnt++);
    return label;
}

char* new_place(char kind){
    char* place = (char*)calloc(10, 1);
    int target;
    if(kind == 'v') {
        target = vCnt++;
    } else if(kind == 't') {
        target = tCnt++;
    }
    sprintf(place, "%c%d", kind, target);
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

void getOutputPath(char *input_path, char *output_path, size_t output_path_size) {
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
    fprintf(syntax_file, "info line %d: pushing scope stack\n", line);
    if (scopeDepth == MAX_DEPTH - 1){
        fprintf(syntax_file, "warning line %d: Scope depth exceed, can't push!\n", line);
        return;
    }
    scopeStack[++scopeDepth] = (TypeTable*) malloc(sizeof(TypeTable));
    memset(scopeStack[scopeDepth] -> isFilled, 0, sizeof(scopeStack[scopeDepth] -> isFilled));
    memset(scopeStack[scopeDepth] -> buckets, 0, sizeof(scopeStack[scopeDepth] -> buckets));
}

void pop(){
    fprintf(syntax_file, "info line %d: popping scope stack\n", line);
    if (scopeDepth == -1){
        fprintf(syntax_file, "warning line %d: Scope stack is empty, can't pop!\n", line);
        return;
    }
    fprintf(syntax_file, "\nBefore:");
    printAllTable();
    scopeDepth--;
    fprintf(syntax_file, "After:");
    printAllTable();
}

void pushExp(bool lvalue, Category exp, Type* type) {
        if (expDepth == MAX_DEPTH - 1) {
        fprintf(syntax_file, "warning line %d: Exp depth exceed, can't push!\n", line);
    }
    Expression* expression = (Expression*)malloc(sizeof(Expression));
    expStack[expDepth++] = expression;
    expression -> lvalue = lvalue;
    expression -> category = exp;
    expression -> type = type;
    if(type!=NULL){
        fprintf(syntax_file, "info line %d: pushing exp %s %s\n", line, categoryToString(expression -> category), type->name);
    }else{
        fprintf(syntax_file, "info line %d: pushing exp %s\n", line, categoryToString(expression -> category));
    }
}

Expression* popExp() {
    Expression* expression = expStack[--expDepth];
    fprintf(syntax_file, "info line %d: popping exp %s\n", line, categoryToString(expression -> category));
    if (expDepth == -1) {
        fprintf(syntax_file, "warning line %d: Exp stack is empty, can't pop!\n", line);
        return 0;
    }
    return expression;
}

void initInsert(char* name) {
    fprintf(syntax_file, "info line %d: initing type, category: %s\n", line, categoryToString(category));
    Type* type = (Type*) malloc(sizeof(Type));
    strcpy(type -> name, name);
    type -> category = category;
    if (category == STRUCTURE){
        type -> structure = structureDec;
    }else {
        type -> structure = NULL;
    }
    strcpy(type -> registerName, new_place('v'));
    insert(type);
    if (!definingStruct) {
        return;
    }
    fprintf(syntax_file, "creating struct var! %s.%s\n", structureDef->name, type->name);
    if (typeList == NULL){
        typeList = (TypeList*)malloc(sizeof(TypeList));
        structureDef -> typeList = typeList;
    }else{
        typeList -> next = (TypeList*)malloc(sizeof(TypeList));
        typeList = typeList -> next;
    }
    typeList -> next = NULL;
    typeList -> type = type;
    structureDef -> typeNum++;
}

void initFunction(char* name) {
    fprintf(syntax_file, "info line %d: initing function name: %s\n", line, name);
    Type* functionType = (Type*)malloc(sizeof(Type));
    strcpy(functionType -> name, name);
    functionType -> category = FUNCTION;
    functionCreate = (Function*) malloc(sizeof(Function));
    functionType -> function = functionCreate;
    functionCreate -> paramNum = 0;
    functionCreate -> varList = NULL;
    functionCreate -> returnCategory = category;
    insert(functionType);
    push();
    declaringFunction = true;
    // tCnt--;
}

void initStruct(char* name){
    fprintf(syntax_file, "info line %d: initing struct, name: %s\n", line, name);
    Type* structureType = (Type*) malloc(sizeof(Type));
    strcpy(structureType -> name, name);
    structureType -> category = STRUCTURE;
    structureDef = (Structure*) malloc(sizeof(Structure));
    structureDef -> typeNum = 0;
    strcpy(structureDef -> name, name);
    structureDef -> typeList = NULL;
    structureType -> structure = structureDef;
    insert(structureType);
    definingStruct = true;
}

void insert(Type* type) {
    if(type->category == FUNCTION){
        fprintf(syntax_file, "info line %d: inserting function: %s\n", line, type -> name);
        if (check(type -> name)){
            fprintf(syntax_file, "Error type 4 at Line %d: \"%s\" is redefined\n", line, type -> name);
            return;
        }
    }else if (type -> category == STRUCTURE) {
        fprintf(syntax_file, "info line %d: inserting structure, struct %s %s\n", line, type -> structure -> name, type -> name);
        if (check(type -> name)) {
            fprintf(syntax_file, "Error type 15 at Line %d: redefine the same structure type\n", line);
            return;
        }    
        insertIntoTypeTable(scopeStack[scopeDepth-1], type);
        return;
    }else {
        fprintf(syntax_file, "info line %d: inserting type: %s %s\n", line, categoryToString(type -> category), type -> name);
        if (check(type -> name)) {
            fprintf(syntax_file, "Error type 3 at Line %d: variable \"%s\" is redefined in the same scope\n", line, type -> name);
            return;
        }
    }
    
    insertIntoTypeTable(scopeStack[scopeDepth], type);
    printAllTable();
}

void clearArray() {
    fprintf(syntax_file, "info line %d: clearing array, name: %s\n", line, arrayType -> name);
    Type* temp = arrayType;
    while(temp != NULL){
        temp = arrayType -> array -> base;
        free(arrayType -> array);
        free(arrayType);
        arrayType = temp;
    }
    arrayType = NULL;
}

bool check(char* name) {
    fprintf(syntax_file, "info line %d: checking type, name: %s\n", line, name);
    for (int i = scopeDepth; i >= 0; i--) {
        if(contain(scopeStack[i], name)) {
            return true;
        }
    }
    return false;
}

Type* get(char* name) {
    fprintf(syntax_file, "info line %d: getting type, name: %s\n", line, name);
    Type* result = NULL;
    for (int i = scopeDepth; i >= 0; i--) {
        result = getType(scopeStack[i], name);
        if(result != NULL) {
            fprintf(syntax_file, "info line %d: result: %s\n", line, categoryToString(result -> category));
            return result;
        }
    }
    return NULL;
}

void printAllTable() {
    fprintf(syntax_file, "\n------printing type table------\n\n");
    for (int i = 0; i <= scopeDepth; i++){
        fprintf(syntax_file, "Type table: %d\n\n", i);
        printTable(scopeStack[i]);
        fprintf(syntax_file, "\n");
    }
}

Category intOperate(char* op) {
    Category exp1 = popExp() -> category, exp2 = popExp() -> category;
    fprintf(syntax_file, "info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    if (exp1 != INT && exp1 != FLOATNUM && exp1 != NUL){
        fprintf(syntax_file, "Error type 7 at Line %d: binary operation on non-number variables\n", line);
    }
    if (exp2 != INT && exp2 != FLOATNUM && exp2 != NUL){
        fprintf(syntax_file, "Error type 7 at Line %d: binary operation on non-number variables\n", line);
    }
    if (exp1 == INT && exp2 == FLOATNUM || exp1 == FLOATNUM && exp2 == INT) {
        fprintf(syntax_file, "Error type 7 at Line %d: unmatching operands\n", line);
    }
    if (exp1 == INT && exp2 == INT || exp1 == FLOAT && exp2 == FLOAT) {
        return exp1;
    }
    return NUL;
}

void boolOperate(char* op) {
    Category exp1 = popExp() -> category, exp2 = popExp() -> category;
    fprintf(syntax_file, "info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    pushExp(false, BOOLEAN, NULL);
}

void handleFunction(char* name){
    Type* functionType = get(name);
    if (functionType == NULL) {
        fprintf(syntax_file, "Error type 2 at Line %d: \"%s\" is invoked without a definition\n", line, name);
        pushExp(false, NUL, NULL);
        return;
    }
    if (functionType -> category != FUNCTION) {
        fprintf(syntax_file, "Error type 11 at Line %d: invoking non-function variable\n", line);
        pushExp(false, NUL, NULL);
        return;
    }
    int paramNum1 = functionType -> function -> paramNum;
    CategoryList* varList1 = functionType -> function -> varList;

    if(functionInvoke == NULL){
        // 无参函数
        pushExp(false, functionType -> function -> returnCategory, NULL);
        return;
    }
    
    int paramNum2 = functionInvoke -> paramNum;
    CategoryList* varList2 = functionInvoke -> varList;
    if (paramNum1 != paramNum2) {
        fprintf(syntax_file, "Error type 9 at Line %d: invalid argument number, except %d, got %d\n", line, paramNum1, paramNum2);
        pushExp(false, functionType -> function -> returnCategory, NULL);
        return;
    }
    while (varList1 != NULL && varList2 != NULL){
        Category category1 = varList1 -> category;
        Category category2 = varList2 -> category;
        fprintf(syntax_file, "info line %d: checking category %s, %s\n", line, categoryToString(category1), categoryToString(category2));
        if (
            category1 != NUL&&
            category2 != NUL&&
            category1 != category2){
            fprintf(syntax_file, "Error type 9 at Line %d: arguments type mismatch, except %s, got %s\n", line, categoryToString(category1), categoryToString(category2));
            break;
        }
        varList1 = varList1 -> next;
        varList2 = varList2 -> next;
    }
    pushExp(false, functionType -> function -> returnCategory, NULL);
    freeFunction(functionInvoke);
    functionInvoke = NULL;
    functionType = NULL;
}

void initArray(char* name, int size, Type* base) {
    fprintf(syntax_file, "info line %d: initing array, size: %d\n", line, size);
    arrayType = (Type*)malloc(sizeof(Type));
    strcpy(arrayType -> name, name);
    arrayType -> category = ARRAY;
    arrayType -> array = NULL;
    if (size == 0){
        return;
    }
    arrayType -> array = (Array*)malloc(sizeof(Array));
    arrayType -> array -> size = size;
    arrayType -> array -> base = base;
}

int yyerror(char *msg) {
    char* syntax_error = "syntax error";
    if(strcmp(msg, syntax_error) != 0){        
        fprintf(syntax_file, "Error type B at Line %d:%s\n", line, msg);
    }
    error = true;
    return 0;
}

int main(int argc, char **argv){
    char *file_path;
    
    scopeStack[0] = (TypeTable*)malloc(sizeof(TypeTable));
    scopeDepth = 0;

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
    code_file = fopen("test_a.ir", "w");
    syntax_file = fopen("syntax.txt", "w");
    debug_file = fopen("test_a_debug.ir", "w");
    if(!(yyin = fopen(file_path, "r"))){
        perror(argv[1]);
        return EXIT_FAIL;
    }

    // category = INT;
    // initFunction("read");

    // category = NUL;
    // initFunction("write");
    // functionCreate -> paramNum = 1;
    // functionCreate -> varList = (CategoryList*)malloc(sizeof(CategoryList));
    // functionCreate -> varList -> category = INT;
    // functionCreate -> varList -> next = NULL;

    // category = NUL;
    // functionCreate = NULL;

    yyparse();
    fclose(output_file);
    return EXIT_OK;
}

void handleParam(){
    if (cateList == NULL){
        cateList = (CategoryList*)malloc(sizeof(CategoryList));
        functionCreate -> varList = cateList;
    }else{
        cateList -> next = (CategoryList*)malloc(sizeof(CategoryList));
        cateList = cateList -> next;
    }
    cateList -> next = NULL;
    cateList -> category = category;
    functionCreate -> paramNum++;
}

void handleID(char* name){
    Type* result = get(name);
    if (result == NULL){
        fprintf(syntax_file, "Error type 1 at Line %d: \"%s\" is used without a definition\n", line, name);
        pushExp(true, NUL, NULL);
        return;
    }

    if (result -> category == NUL) {
        fprintf(syntax_file, "Error type 2 at line %d: type had been used without definition before, name: %s\n", line, name);
        pushExp(true, NUL, result);
    } else if (result -> category == ARRAY) {
        pushExp(true, ARRAY, result);
    } else if (result -> category == STRUCTURE){
        pushExp(true, STRUCTURE, result);
    } else if (result -> category == FUNCTION){
        fprintf(syntax_file, "Error type 11 at line %d: function invoked without ()\n", line);
        pushExp(true, result -> function -> returnCategory, result);
    } else {
        pushExp(true, result -> category, result);
    }
}

void handleExpArray(){
    Expression* exp1 = popExp();
    Expression* exp2 = popExp();
    if (exp2 -> category != ARRAY){
        fprintf(syntax_file, "Error type 10 at line %d: indexing on non-array variable\n", line);
        pushExp(true, exp2 -> category, NULL);
        return;
    }
    if (exp1 -> category != INT){
        fprintf(syntax_file, "Error type 12 at Line %d: indexing by non-integer\n", line);
    }
    Type* base = exp2 -> type -> array -> base;
    pushExp(true, base -> category, base);
}

void handleExpFetchStructure(char* name) {
    Expression* exp = popExp();
    if (exp -> category != STRUCTURE){
        fprintf(syntax_file, "Error type 13 at Line %d: accessing with non-struct variable\n", line);
        pushExp(exp->lvalue, NUL, NULL);
        return;
    }
    Type* structureType = exp -> type;
    Type* result = structureFind(structureType -> structure -> typeList, name);
    if(result == NULL){
        fprintf(syntax_file, "Error type 14 at Line %d: accessing an undefined structure member %s.%s\n", line, structureType->name, name);
        pushExp(exp->lvalue, NUL, NULL);
        return;
    }
    pushExp(exp -> lvalue, result -> category, result);
    
}

void handleReturn() {
    Category find = popExp() -> category;
    Category expected = functionCreate -> returnCategory;
    if (find != expected){
        fprintf(syntax_file, "Error type 8 at Line %d: incompatiable return type, except: %s, got: %s\n", line, categoryToString(expected), categoryToString(find));
    }
    fprintf(syntax_file, "info line %d: returning %s\n", line, categoryToString(find));
}