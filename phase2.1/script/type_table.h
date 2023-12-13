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
    BOOLEAN
} Category;

typedef struct Type {
    char* name;
    Category category;
    union{
        struct Array* array;
        struct TypeList* structure;
        // struct TypeTable* structure;
        // struct Structure* structure;
        struct Function* function;
        char* string;
    };
}Type;


typedef struct Function{
    int paramNum;
    Category returnCategory;
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

bool insertIntoTypeTable(TypeTable* typeTable, Type* type, int line);

Type* getType(TypeTable* typeTable, char* name);

void printTable(TypeTable* typeTable);

void printType(Type* type);

char* categoryToString(Category category);

void freeTypeTable(int line, TypeTable* typeTable);

void freeType(int line, Type* type);

void freeTypeList(int line, TypeList* typeList);

void freeFunction(int line, Function* function);

bool checkTypeSame(Type* type1, Type* type2);

bool checkStructureSame(TypeList* typeList1, TypeList* typeList2);
#endif

