#ifndef Type_TABLE
#define Type_TABLE
#define TABLE_SIZE 97
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

typedef struct Type {
    char* name;
    enum {INT, FLOATE, CHAR, ARRAY, STRUCTURE, FUNCTION, STRING} category;
    union{
        struct Array* array;
        struct TypeList* structure;
        // Structure* structure;
        struct Function* function;
        char* string;
    };
}Type;

typedef struct Function{
    int paramNum;
    struct Type* returnType;
    struct TypeList* varList;
} Function;

typedef struct Array {
    struct Type* base;
    int size;
}Array;

typedef struct TypeList {
    struct Type* type;
    struct TypeList* next;
} TypeList;

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

typedef struct Structure{
    char* name;
    int intNum;
    int floatNum;
    int charNum;
    int stringNum;
    struct PriorityQueue* arrays;
    struct PriorityQueue* structures;
} Structure;


unsigned int hashFunction(char* name);

HashNode* createHashNode(Type* type);

bool insertIntoTypeTable(TypeTable* typeTable, Type* type);

Type* getType(TypeTable* typeTable, char* name);

void printTable(TypeTable* typeTable);

void printType(Type* type);

void freeTypeTable(TypeTable* typeTable);

void freeType(Type* type);

void freeTypeList(TypeList* typeList);

void freeFunction(Function* function);

bool checkTypeSame(Type* type1, Type* type2);

bool checkStructureSame(TypeList* typeList1, TypeList* typeList2);
#endif

