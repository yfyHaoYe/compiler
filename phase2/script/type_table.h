#ifndef Type_TABLE
#define Type_TABLE
#define TABLE_SIZE 97
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

typedef struct Type {
    char name[32];
    int init;
    enum {PRIMITIVE, ARRAY, STRUCTURE, FUNCTION} category;
    union{
        enum {INT, FLOAT, CHAR} primitive;
        struct Array *array;
        struct FieldList *structure;
        struct Function *function;
    };
}Type;

typedef struct Function{
    char* name;
    Type* returnType;
    int paramNum;
    struct FieldList* varList;
} Function;

typedef struct Array {
    struct Type *base;
    int size;
}Array;

typedef struct FieldList {
    char name[32];
    struct Type *type;
    struct FieldList *next;
}FieldList;

typedef struct HashNode {
    char* name;
    Type* type;
    struct HashNode* next;
} HashNode;


typedef struct {
    HashNode* buckets[TABLE_SIZE];
    int isFilled[TABLE_SIZE];
} TypeTable;

unsigned int hashFunction(char* name);

HashNode* createHashNode(char* name, Type* type);

int insertIntoTypeTable(TypeTable* typeTable, char* name, Type* type);

Type* getType(TypeTable* typeTable, char* name);

void freeTypeTable(TypeTable* typeTable);

bool isContains(TypeTable* typeTable, char* name);

int checkType(Type* type1, Type* type2);
#endif

