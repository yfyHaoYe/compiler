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
    TypeTable* scopeStack[50];
    int scopeDepth;
    // type: 在创建任意一个type时都创建在这里，在insert后置NULL
    Type* type;
    // functionType: 在创建函数时创建在这里，通过insertFunction插入，随后置NULL
    Type* functionType;
    // structureType: 在创建Structure时创建在这里，通过insertStructure插入，随后置NULL
    Type* structureType;
    // 用于在创建带参函数时，在识别到FunDec而非"{"时执行push
    bool creatingFunction;

    void init(char* category);
    void initFunction();
    void initStruct(char* name);
    void initArray(int size);
    bool insert();
    bool insertClear();
    bool insertRecreate();
    bool insertFunction();
    bool insertStructure();
    void clearArray();
    bool check(char* name);
    Type* get(char* name);
    void freeLastTable();
    void printAllTable();
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
    insertFunction();
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
    clearArray();
}
|
// modified: can't handle VarDec COMMA ExtDecList, changed to:
    ExtDecList COMMA VarDec{
    $$ = createNode("ExtDecList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
    insert();
    clearArray();
}
;
/* specifier */
Specifier : TYPE {
    $$ = createNode("Specifier", "", $1.line, 1, createNode("TYPE", $1.string, $1.line, 0));
    init($1.string);
}
| StructSpecifier {
    $$ = createNode("Specifier", "", $1->line, 1, $1);
}
;

StructSpecifier : StructDec LC DefList RC {
    $$ = createNode("StructSpecifier", "", $1 -> line, 5, $1 -> children[0], $1 -> children[1], createNode("LC", "", $2, 0), $3, createNode("RC", "", $4, 0));
    insertStructure();
}
| StructDec {
    $$ = createNode("StructSpecifier", "", $1 -> line, 2, $1 -> children[0], $1 -> children[1]);
    insertStructure();
}
;
/* declarator */
// modified: add StructDec
StructDec : STRUCT ID {
    $$ = createNode("StructDec", "", $1, 2, createNode("STRUCT", "", $1, 0), createNode("ID", $2.string, $2.line, 0));
    initStruct($2.string);
}
;
VarDec : ID {
    $$ = createNode("VarDec", "", $1.line, 1, createNode("ID", $1.string, $1.line, 0));
    type -> name = $1.string;
}
| VarDec LB INT RB {
    $$ = createNode("VarDec", "", $1->line, 4, $1, createNode("LB", "", $2, 0), createNode("INT", $3.string, $3.line, 0), createNode("RB", "", $4, 0));
    // TODO: is $3.string a int?
    initArray(atoi($3.string));
}
| VarDec LB INT error {
    yyerror(" Missing closing square bracket ']'");
}
;
FunDec : FunID LP VarList RP {
    $$ = createNode("FunDec", "", $1->line, 4, $1, createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0));
    functionType -> name = $1 -> value;
}
| FunID LP RP {
    $$ = createNode("FunDec", "", $1->line, 3, $1, createNode("LP", "", $2, 0), createNode("RP", "", $3, 0));
    functionType -> name = $1 -> value;
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
    initFunction();
}
;
VarList : ParamDec COMMA VarList {
    $$ = createNode("VarList", "", $1->line, 3, $1, createNode("COMMA", "", $2, 0), $3);
    TypeList* last = (TypeList*)malloc(sizeof(TypeList));
    last -> type = type;
    last -> next = functionType -> function -> varList;
    functionType -> function -> varList = last;
    type = NULL;
}
| ParamDec {
    $$ = createNode("VarList", "", $1->line, 1, $1);
    functionType -> function -> varList -> type = type;
    type = NULL;
}
;
ParamDec : Specifier VarDec {
    $$ = createNode("ParamDec", "", $1->line, 2, $1, $2);
    if (!creatingFunction){
        initFunction();
    }
    functionType -> function -> paramNum++;
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
    // TODO: checkReturn()
}
| IF LP Exp RP Stmt %prec LOWER {
    $$ = createNode("Stmt", "", $1, 5, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    // TODO: Exp should be bool
}
| IF LP Exp RP Stmt ELSE Stmt {
    $$ = createNode("Stmt", "", $1, 7, createNode("IF", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5, createNode("ELSE", "", $6, 0), $7);
    // TODO: Exp should be bool
}
| WHILE LP Exp RP Stmt {
    $$ = createNode("Stmt", "", $1, 5, createNode("WHILE", "", $1, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $4, 0), $5);
    // TODO: Exp should be bool
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
    free(type);
    type = NULL;
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
    insertRecreate();
}
| VarDec ASSIGN Exp {
    $$ = createNode("Dec", "", $1->line, 3, $1, createNode("ASSIGN", "", $2, 0), $3);
    insertRecreate();
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
    // TODO: which type?
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
    if (!check($1.string)){
        // TODO: error: can't find id
    }
    type = get();
}
| INT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("INT", $1.string, $1.line, 0));
    init("int");
}
| FLOAT {
    $$ = createNode("Exp", "", $1.line, 1, createNode("FLOAT", $1.string, $1.line, 0));
    init("float");
}
| CHAR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("CHAR", $1.string, $1.line, 0));
    init("char");
}
| STR {
    $$ = createNode("Exp", "", $1.line, 1, createNode("STR", $1.string, $1.line, 0));
    init("string");
}
| ID LP Args RP {
    $$ = createNode("Exp", "", $1.line, 4, createNode("ID", $1.string, $1.line, 0), createNode("LP", "", $2, 0), $3, createNode("RP", "", $2, 0));
    // TODO: Function invoking
    init("function");
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
            my_print("  ");
        }
        if(node->numChildren == 0){
            if(strlen(node->value) == 0){
                my_print("%s\n", node->type);
            }else{
                my_print("%s: %s\n", node->type, node->value);
            }
        }
        else {
            my_print("%s (%d)\n", node->type, node->line);
        }
    }

    for (int i = 0; i < node->numChildren; i++) {
        printParseTree(node->children[i], level + 1);
    }
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
    if (scopeDepth == MAX_DEPTH){
        printf("Scope depth exceed, can't push!\n");
        return;
    }
    scopeStack[++scopeDepth] = (TypeTable*) malloc(sizeof(TypeTable));
}

void pop(){
    if (scopeDepth == -1){
        printf("Scope is empty, can't pop!\n");
        return;
    }
    freeTypeTable(scopeStack[scopeDepth--]);
    creatingFunction = false;
}

void init(char* category) {
    if (type != NULL){
        printf("type isn't correct clear! find in init\n");
    }
    type = (Type*) malloc(sizeof(Type));
    if (strcmp(category, "int")) {
        type -> category = INT;
    }else if (strcmp(category, "float")) {
        type -> category = FLOATE;
    }else if (strcmp(category, "char")) {
        type -> category = CHAR;
    }else if (strcmp(category, "array")) {
        type -> category = ARRAY;
        type -> array = (Array*) malloc(sizeof(Array));
    }else if (strcmp(category, "string")){
        type -> category = STRING;
    }else{
        // TODO: something wrong
        printf("category can't organized! find in init\n");
    }
}
void initFunction(){
    if (functionType != NULL){
        printf("function type isn't correct clear! find in initFunction\n");
    }
    push();
    creatingFunction = true;
    functionType = (Type*)malloc(sizeof(Type));
    functionType -> category = FUNCTION;
    functionType -> function = (Function*) malloc(sizeof(Function));
    functionType -> function -> paramNum = 0;
    functionType -> function -> returnType = type;
    functionType -> function -> varList = (TypeList*)malloc(sizeof(TypeList));
}
void initStruct(char* name){
    if (structureType != NULL){
        printf("structure type isn't correct clear! find in initStruct\n");
    }
    structureType = (Type*) malloc(sizeof(Type));
    structureType -> name = name;
    structureType -> category = STRUCTURE;
    structureType -> structure = (TypeTable*) malloc(sizeof(TypeTable));
}

void initArray(int size){
    Array* array = (Array*)malloc(sizeof(Array));
    array -> base = type;
    array -> size = size;
    type = (Type*)malloc(sizeof(Type));
    type -> name = array -> base -> name;
    type -> category = ARRAY;
    type -> array = array;
}

bool insert() {
    if (!check(type -> name)) {
        // TODO: type name same error
        return false;
    }
    bool success = insertIntoTypeTable(scopeStack[scopeDepth], type);
    if (!success) {
        // TODO: something is wrong 
        // printf("why?!");
    }
    return success;
}

bool insertClear(){
    bool success = insert();
    type = NULL;
    return success;
}
bool insertRecreate() {
    bool success = insert();
    Type* temp = (Type*)malloc(sizeof(Type));
    clearArray();
    temp -> name = temp -> name;
    temp -> category = type -> category;
    // TODO: handle more struct
    type = temp;
}

void clearArray() {
    while(type -> category == ARRAY){
        type = type -> array -> base;
    }
}

bool insertFunction(){
    // TODO: same name function handling.
    if (!check(functionType -> name)){
        // TODO: function same name error
        return false;
    }
    bool success = insertIntoTypeTable(scopeStack[scopeDepth], functionType);
    if (!success) {
        // TODO: something is wrong 
        // printf("why?!\n");
    }
    functionType = NULL;
    return success;
}

bool insertStructure(){
    if (!check(structureType -> name)){
        // TODO: structure same name error
    }
    // TODO: structure insert method
    bool success = insertIntoTypeTable(scopeStack[scopeDepth], structureType);
    if (!success) {
        // TODO: something is wrong 
        // printf("why?!\n");
    }
    structureType = NULL;
    return success;
}

bool check(char* name) {
    for (int i = scopeDepth; i>=0; i--) {
        if(contain(scopeStack[i], name)) {
            return true;
        }
    }
    return false;
}

Type* get(char* name) {
    Type* result;
    for (int i = scopeDepth; i>=0; i--) {
        result = getType(scopeStack[i], name);
        if(result != NULL) {
            return result;
        }
    }
    return NULL;
}

void printAllTable() {
    for (int i = 0; i <= scopeDepth; i++){
        printTable(scopeStack[i]);
    }
}
