#ifndef Type_TABLE
#define Type_TABLE
#define TABLE_SIZE 97
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>


typedef enum Category{
    INT = 1,
    FLOATNUM,
    CHAR,
    ARRAY,
    STRUCTURE,
    FUNCTION,
    STRING,
    BOOLEAN,
    NUL
} Category;

typedef struct Type {
    char name[50];
    Category category;
    bool init;
    char registerName[10];
    union{
        struct Array* array;
        struct Structure* structure;
        // struct TypeTable* structure;
        // struct Structure* structure;
        struct Function* function;
        // char string[50];
    };
}Type;

typedef struct TypeList {
    struct Type* type;
    struct TypeList* next;
} TypeList;

typedef struct Structure{
    char name[50];
    TypeList* typeList;
} Structure;

typedef struct Function{
    int paramNum;
    Category returnCategory;
    struct CategoryList* varList;
} Function;

typedef struct Array {
    struct Type* base;
    int size;
}Array;


typedef struct CategoryList
{
    Category category;
    struct CategoryList* next;
} CategoryList;

typedef struct HashNode {
    struct Type* type;
    struct HashNode* next;
} HashNode;

typedef struct TypeTable{
    struct HashNode* buckets[TABLE_SIZE];
    bool isFilled[TABLE_SIZE];
} TypeTable;

typedef struct PriorityQueue{
    int size;
    // ...
} PriorityQueue;

typedef struct Expression{
    Category category;
    bool lvalue;
} Expression;

unsigned int hashFunction(char* name);

HashNode* createHashNode(Type* type);

void insertIntoTypeTable(TypeTable* typeTable, Type* type);

Type* getType(TypeTable* typeTable, char* name);

Category structureFind(TypeList* typeList, char* name);

void printTable(TypeTable* typeTable);

void printType(Type* type);

void printCategoryList(CategoryList* categoryList);

char* categoryToString(Category category);

void freeTypeTable(TypeTable* typeTable);

void freeType(Type* type);

void freeCategoryList(CategoryList* CategoryList);

void freeTypeList(TypeList* typeList);

void freeFunction(Function* function);

bool checkTypeSame(Type* type1, Type* type2);

bool checkStructureSame(TypeList* typeList1, TypeList* typeList2);
#endif

