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
    // functionType: 在创建函数时创建在这里，通过insertFunction插入，随后置NULL
    Type* functionType;
    // structureType: 在创建Structure时创建在这里，通过insertStruct插入，随后置NULL
    Type* structureType;
    // 用于在创建带参函数时，在识别到FunDec而非"{"时执行push
    bool creatingFunction;

    void pushExp(Category exp);
    Category popExp();

    void init(Category category);
    void initFunction();
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
| // StructSpecifier SEMI
    Specifier SEMI {
    $$ = createNode("ExtDef", "", $1->line, 2, $1, createNode("SEMI", "", $2, 0));
    // default struct
}
| Specifier FunDec CompSt {
    $$ = createNode("ExtDef", "", $1->line, 3, $1, $2, $3);
    my_print(INFO, "info line %d: function end\n", line);
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
| StructSpecifier {
    $$ = createNode("Specifier", "", $1->line, 1, $1);
}
;

StructSpecifier : StructDec LC DefList RC {
    $$ = createNode("StructSpecifier", "", $1 -> line, 5, $1 -> children[0], $1 -> children[1], createNode("LC", "", $2, 0), $3, createNode("RC", "", $4, 0));
}
| StructDec {
    $$ = createNode("StructSpecifier", "", $1 -> line, 2, $1 -> children[0], $1 -> children[1]);
}
;
/* declarator */
// modified: add StructDec
StructDec : STRUCT ID {
    $$ = createNode("StructDec", "", $1, 2, createNode("STRUCT", "", $1, 0), createNode("ID", $2.string, $2.line, 0));
    initStruct($2.string);
    insertStruct();
}
;
VarDec : ID {
    $$ = createNode("VarDec", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    type -> name = $1.string;
    my_print(INFO, "info line %d: creating VarDec, name: %s\n", line, type -> name);
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
    my_print(INFO, "info line %d: creating fundec, name: %s, return: %s\n", $1 -> line, $1 -> value, categoryToString(functionType -> function -> returnCategory));
    functionType -> name = $1 -> value;
    insertFunction();
}
|FunID LP RP {
    $$ = createNode("FunDec", $1 -> value, $1->line, 3, $1, createNode("LP", "", $2, 0), createNode("RP", "", $3, 0));
    my_print(INFO, "info line %d: creating fundec, name: %s\n", $1 -> line, $1 -> value);
    functionType -> name = $1 -> value;
    insertFunction();
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
    initFunction($1.line);
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
    $$ = createNode("ParamDec", "", $1->line, 2, $1, $2);
    // insert();
    TypeList* last = (TypeList*)malloc(sizeof(TypeList));
    last -> type = type;
    last -> next = functionType -> function -> varList;
    functionType -> function -> varList = last;
    functionType -> function -> paramNum++;
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
    // TODO: checkReturn()
    Category find = popExp();
    Category expected = functionType -> function -> returnCategory;
    if (find != expected){
        my_print(ERROR, "error line %d: return type mismatch, expected: %s, find: %s\n", line, categoryToString(expected), categoryToString(find));
    }
    my_print(INFO, "info line %d: returning %s\n", $1, categoryToString(find));
    if (expDepth != 0){
        my_print(WARNING, "warning line %d: exp stack isn't clear correctly, left: %d\n", line, expDepth);
        expDepth = 0;
    }
}
| IF LP Exp RP Stmt %prec LOWER {
    $$ = createNode("Stmt", "", $1, 5, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    // TODO: Exp should be bool
    popExp();
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", $1, 7, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5, createNode("ELSE", "", $6, 0), $7);
    // TODO: Exp should be bool
    popExp();
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", $1, 5, createNode("WHILE", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    // TODO: Exp should be bool
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
    $$->empty = true;
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
    insert();
    recreate();
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    insert();
    recreate();
    popExp();
}
;

/* Expression */
Exp : Exp ASSIGN Exp {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    // TODO: return type null or type of exp1?
    // TODO: type equal check
    // TODO: rvalue check
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
    $$ = createNode("Exp", "", $1, 3, createNode("LP", "", $1, 0), $2, createNode("RP", "", $3, 0));
}
| MINUS Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("MINUS", "", $1, 0), $2);
    Category exp = popExp();
    my_print(INFO, "info line %d: minus %s \n", line, categoryToString(exp));
    if (exp != INT && exp != FLOATNUM && exp != 0){
        my_print(ERROR, "error line %d: exp type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp));
    }
    pushExp(INT);
}
| NOT Exp {
    $$ = createNode("Exp", "", $1, 2, createNode("NOT", "", $1, 0), $2);
    Category exp = popExp();
    my_print(INFO, "info line %d: not %s \n", line, categoryToString(exp));
    if (exp != BOOLEAN && exp != 0){
        my_print(ERROR, "error line %d: exp type mismatch, expected: boolean, find: %s\n", line, categoryToString(exp));
    }
    pushExp(BOOLEAN);
}
| ID LP RP {
    $$ = createNode("Exp", "", $1.line, 3, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $1.line, 0), createNode("RP", "", $1.line, 0));
    // TODO: function check
}
| Exp LB Exp RB {
    $$ = createNode("Exp", "", $1->line, 4, $1, createNode("LB", "", $2, 0), $3, createNode("RB", "", $4, 0));
    // TODO: array check
}
| Exp DOT ID {
    $$ = createNode("Exp", "", $1->line, 3, $1, createNode("DOT", "", $2, 0), createNode("ID", $3.string, $3.line, 0));
    // TODO: structure check
}
| ID {
    $$ = createNode("Exp", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    Type* result = get($1.string);
    if (result != NULL){
        pushExp(result -> category);
    } else {
        pushExp(0);
        if (type -> category = 0) {
            my_print(WARNING, "warning line %d: type had been used without definition before, name: %s\n", line, $1.string);
        } else {
            // error: can't find id
            my_print(ERROR, "Error type 1 at Line %d: \"%s\" is used without a definition\n", line, $1.string);
            Type* temp = (Type*)malloc(sizeof(TYPE));
            temp -> name = $1.string;
            insertIntoTypeTable(scopeStack[scopeDepth], type, line);
        }
    }
}
| INT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("INT", $1.string, $1.line, 0));
    pushExp(INT);
}
| FLOAT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("FLOAT", $1.string, $1.line, 0));
    pushExp(FLOATNUM);
}
| CHAR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("CHAR", $1.string, $1.line, 0));
    pushExp(CHAR);
}
| STR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("STR", $1.string, $1.line, 0));
    pushExp(STRING);
}
| ID LP Args RP {
    $$ = createNode("Exp", "", $1.line, 4, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $2, 0));
    // TODO: Function invoking
    functionType = get($1.string);
    if (functionType -> category != FUNCTION) {
        // TODO: error
    }
    // TODO: argument check
    TypeList* varlist = functionType -> function -> varList;
    // if (checkList(varlist)) {}
    // type = type -> function -> returnCategory;
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
            my_print(PHASE1, "  ");
        }
        if(node->numChildren == 0){
            if(strlen(node->value) == 0){
                my_print(PHASE1, "%s\n", node->type);
            }else{
                my_print(PHASE1, "%s: %s\n", node->type, node->value);
            }
        }
        else {
            my_print(PHASE1, "%s (%d)\n", node->type, node->line);
        }
    }

    for (int i = 0; i < node->numChildren; i++) {
        printParseTree(node->children[i], level + 1);
    }
}

int yyerror(const char *msg) {
    char* syntax_error = "syntax error";
    if(strcmp(msg, syntax_error) != 0){        
        my_print(ERROR, "error type B at Line %d:%s\n", line, msg);
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
    my_print(INFO, "info line %d: pushing scope stack\n", line);
    if (scopeDepth == MAX_DEPTH - 1){
        my_print(WARNING, "warning line %d: Scope depth exceed, can't push!\n", line);
        return;
    }
    scopeStack[++scopeDepth] = (TypeTable*) malloc(sizeof(TypeTable));
}

void pop(){
    my_print(INFO, "info line %d: popping scope stack\n", line);
    if (scopeDepth == -1){
        my_print(WARNING, "warning line %d: Scope stack is empty, can't pop!\n", line);
        return;
    }
    printAllTable();
    freeTypeTable(line, scopeStack[scopeDepth--]);
    my_print(TABLE, "\nUpdated table:\n", TABLE);
    printAllTable();
    creatingFunction = false;
}

void pushExp(Category exp) {
    my_print(INFO, "info line %d: pushing exp %s\n", line, categoryToString(exp));
    if (expDepth == MAX_DEPTH - 1) {
        my_print(WARNING, "warning line %d: Exp depth exceed, can't push!\n", line);
    }
    expStack[expDepth++] = exp;
}

Category popExp() {
    my_print(INFO, "info line %d: popping exp %s\n", line, categoryToString(expStack[expDepth]));
    if (expDepth == -1) {
        my_print(WARNING, "warning line %d: Exp stack is empty, can't pop!\n", line);
        return 0;
    }
    return expStack[--expDepth];
}

void init(Category category) {
    my_print(INFO, "info line %d: initing type, category: %s\n", line, categoryToString(category));
    if (type != NULL){
        my_print(WARNING, "warning line %d: type isn't correctly clear! name: %s, category: %s\n", line, type -> name, categoryToString(type -> category));
    }
    type = (Type*) malloc(sizeof(Type));
    type -> category = category;
    if (category == ARRAY) {
        type -> array = (Array*)malloc(sizeof(Array));
    }
}

void initFunction() {
    my_print(INFO, "info line %d: initing function type\n", line);
    if (functionType != NULL){
        my_print(WARNING, "warning line %d: function type isn't correctly clear!\n", line);
    }
    push();
    creatingFunction = true;
    functionType = (Type*)malloc(sizeof(Type));
    functionType -> category = FUNCTION;
    functionType -> function = (Function*) malloc(sizeof(Function));
    functionType -> function -> paramNum = 0;
    functionType -> function -> returnCategory = type -> category;
    functionType -> function -> varList = (TypeList*)malloc(sizeof(TypeList));
    setNull();
}

void initStruct(char* name){
    my_print(INFO, "info line %d: initing struct, name: %s\n", line, structureType -> name);
    if (structureType != NULL){
        my_print(WARNING, "warning line %d: struct isn't correctly clear! name: %s\n", line, type -> name);
    }
    structureType = (Type*) malloc(sizeof(Type));
    structureType -> name = name;
    structureType -> category = STRUCTURE;
    structureType -> structure = (TypeList*) malloc(sizeof(TypeList));
}

void initArray(int size){
    my_print(INFO, "info line %d: initing array, name: %s\n", line, type -> name);
    if (type != NULL){
        my_print(WARNING, "warning line %d: type isn't correctly clear\n", line);
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
    // my_print(INFO, "info line %d: inserting type: %s %s\n", line, categoryToString(type -> category), type -> name);
    // if (check(type -> name)) {
    //     // TODO: type name same error
    //     my_print(ERROR, "error: why?\n");
    //     return false;
    // }
    // printf("hello world\n");
    // bool success = insertIntoTypeTable(scopeStack[scopeDepth], type, line);
    // if (!success) {
        // TODO: something is wrong
        // return false;
    // }
    // printAllTable();
    // return success;
    return true;
}

bool insertFunction(){
    my_print(INFO, "info line %d: inserting function: %s()\n", line, functionType -> name);
    // TODO: same name function handling.
    if (check(functionType -> name)){
        // TODO: function same name error
        return false;
    }
    bool success = insertIntoTypeTable(scopeStack[scopeDepth - 1], functionType, line);
    if (!success) {
        // TODO: something is wrong 
    }
    printAllTable();
    return success;
}

bool insertStruct(){
    my_print(INFO, "info line %d: inserting structure, struct %s\n", line, structureType -> name);
    if (check(structureType -> name)){
        // TODO: structure same name error
    }
    // TODO: structure insert method
    bool success = insertIntoTypeTable(scopeStack[scopeDepth], structureType, line);
    if (!success) {
        // TODO: something is wrong 
    }
    structureType = NULL;
    printAllTable();
    return success;
}

void clear(){
    my_print(INFO, "info line %d: clearing type, name: %s\n", line, type -> name);
    // free(type);
    freeType(line, type);
    type = NULL;
}

void setNull() {
    my_print(INFO, "info line %d: setting type to NULL, current: %s %s\n", line, categoryToString(type -> category), type -> name);
    type = NULL;
}

void clearArray() {
    my_print(INFO, "info line %d: clearing array, name: %s\n", line, type -> name);
    while(type -> category == ARRAY){
        type = type -> array -> base;
    }
}

bool recreate() {
    my_print(INFO, "info line %d: recreating type, category: %s\n", line, categoryToString(type -> category));
    Type* temp = (Type*)malloc(sizeof(Type));
    if (type -> category == ARRAY) {
        clearArray();
    }
    temp -> name = type -> name;
    temp -> category = type -> category;
    // TODO: handle struct
    type = temp;
}

bool check(char* name) {
    my_print(INFO, "info line %d: checking type, name: %s, scopedepth: %d\n", line, name, scopeDepth);
    printAllTable();
    for (int i = scopeDepth; i >= 0; i--) {
        if(contain(scopeStack[i], name)) {
            return true;
        }
    }
    return false;
}

Type* get(char* name) {
    my_print(INFO, "info line %d: getting type, name: %s\n", line, name);
    Type* result = NULL;
    for (int i = scopeDepth; i >= 0; i--) {
        result = getType(scopeStack[i], name);
        if(result != NULL) {
            return result;
        }
    }
    return NULL;
}

void printAllTable() {
    if (!table) {
        return;
    }
    my_print(TABLE, "\n------printing type table------\n\n");
    for (int i = 0; i <= scopeDepth; i++){
        my_print(TABLE, "Type table: %d\n\n", i);
        printTable(scopeStack[i]);
    }
}

void intOperate(char* op) {
    Category exp1 = popExp(), exp2 = popExp();
    my_print(INFO, "info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    if (exp1 != INT && exp1 != FLOATNUM && exp1 != 0){
        my_print(ERROR, "error line %d: exp 1 type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp1));
    }
    if (exp2 != INT && exp2 != FLOATNUM && exp2 != 0){
        my_print(ERROR, "error line %d: exp 2 type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp2));
    }
}


void boolOperate(char* op) {
    Category exp1 = popExp(), exp2 = popExp();
    my_print(INFO, "info line %d: %s %s %s \n", line, categoryToString(exp1), op, categoryToString(exp2));
    if (exp1 != BOOLEAN && exp1 != 0){
        my_print(ERROR, "error line %d: exp 1 type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp1));
    }
    if (exp2 != BOOLEAN && exp2 != 0){
        my_print(ERROR, "error line %d: exp 2 type mismatch, expected: int or float, find: %s\n", line, categoryToString(exp2));
    }
}