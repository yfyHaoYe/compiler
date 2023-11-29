#ifndef Type_TABLE
#define Type_TABLE
#define TABLE_SIZE 97
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

typedef struct Type {
    char name[32];
    enum {PRIMITIVE, ARRAY, STRUCTURE} category;
    union{
        enum {INT, FLOAT, CHAR} primitive;
        struct Array *array;
        struct FieldList *structure;
    };
}Type;

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

unsigned int hashFunction(const char* name);

HashNode* createHashNode(const char* name, Type* type);

int insertIntoTypeTable(TypeTable* typeTable, const char* name, Type* type);

HashNode* getValuesFromTypeTable(TypeTable* typeTable, const char* name);

void freeTypeTable(TypeTable* typeTable);

bool isContains(TypeTable* typeTable, const char* name);
#endif

