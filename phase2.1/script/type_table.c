#include "type_table.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>


unsigned int hashFunction(char* name){
    unsigned int hash = 0;
    unsigned int i;
    unsigned int len = strlen(name);
    for (i = 0; i < len; i++) {
        hash = (hash << 5) + name[i];
    }
    unsigned int myint =  hash % TABLE_SIZE;
    return myint;
}

HashNode* createHashNode(Type* type){
    HashNode* node = (HashNode*)malloc(sizeof(HashNode));
    node->type = type;
    node->next = NULL;
    return node;
}

void insertIntoTypeTable(TypeTable* typeTable, Type* type){
    unsigned int hash = hashFunction(type -> name);
    HashNode* node = createHashNode(type);
    if (!typeTable -> isFilled[hash]) {
        typeTable -> isFilled[hash] = 1;
        typeTable -> buckets[hash] = node;
        return;
    }
    HashNode* currentNode = typeTable -> buckets[hash];
    HashNode* pre;
    while(currentNode != NULL){
        pre = currentNode;
        currentNode = currentNode -> next;
    }
    pre -> next = node;
}

bool contain(TypeTable* typeTable, char* name){
    unsigned int hash = hashFunction(name);
    if(!typeTable -> isFilled[hash]){
        return false;
    }
    HashNode* currentNode = typeTable -> buckets[hash];
    while(currentNode != NULL){
        if (strcmp(currentNode -> type -> name, name) == 0) {
            return true;
        }
        currentNode = currentNode->next;
    }
}

bool checkTypeSame(Type* type1, Type* type2){
    if(type1 == NULL && type2 == NULL){
        return true;
    }
    
    if (type1 == NULL || type2 == NULL || type1 -> category != type2 -> category){
        return false;
    }

    if (type1 -> category == ARRAY){
        return checkTypeSame(type1 -> array -> base, type2 -> array -> base);
    }
    
    if (type1 -> category == STRUCTURE){
        return checkStructureSame(type1 -> structure -> typeList, type2 -> structure -> typeList);
    }

    if (type1 -> category == FUNCTION){
        return false;
    }

    printf("Type categorys can't recognize, find in checkTypeSame, name1:%s, name2:%s\n", type1 -> name, type2 -> name);
    return false;
}

bool checkStructureSame(TypeList* structure1, TypeList* structure2){
    if(structure1 == NULL && structure2 == NULL){
        return true;
    }
    
    if(structure1 == NULL || structure2 == NULL || checkTypeSame(structure1 -> type, structure2 -> type) == false){
        return false;
    }

    return checkStructureSame(structure1 -> next, structure2 -> next);
}

Type* getType(TypeTable* typeTable, char* name) {
    unsigned int hash = hashFunction(name);
    HashNode* currentNode = typeTable -> buckets[hash];
    if (!typeTable -> isFilled[hash]){
        return NULL;
    }
    while (currentNode != NULL) {
        if (strcmp(currentNode -> type -> name, name) == 0) {
            return currentNode -> type;
        }
        currentNode = currentNode -> next;
    }
    return NULL;
}

Category structureFind(TypeList* typeList, char* name) {
    printf("info finding %s in typelist\n", name);
    while (typeList != NULL && strcmp(typeList -> type -> name, name)!=0){
        typeList = typeList -> next;
    }
    if(typeList == NULL){
        return NUL;
    }
    return typeList -> type -> category;
}

void printTable(TypeTable* typeTable){
    for (int i = 0; i < TABLE_SIZE; i++){
        if (!typeTable -> isFilled[i]){
            continue;
        }
        HashNode* node = typeTable -> buckets[i];
        while (node != NULL) {
            printType(node -> type);
            node = node -> next;
        }
    }
}

void printType(Type* type){
    if (type -> category == STRUCTURE) {
        printf("Type name: %s, category: struct %s\n", type -> name, type -> structure -> name);
        return;
    }
    printf("Type name: %s, category: %s\n", type -> name, categoryToString(type -> category));
    if(type -> category == FUNCTION){
        printCategoryList(type -> function -> varList);
    }
}

void printCategoryList(CategoryList* categoryList) {
    while (categoryList != NULL)
    {
        printf("param: %s\n", categoryToString(categoryList->category));
        categoryList = categoryList -> next;
    }
    
}

char* categoryToString(Category category) {
    if (category == INT) {
        return "int";
    }
    else if (category == FLOATNUM) {
        return "float";
    }
    else if (category == CHAR) {
        return "char";
    }
    else if (category == ARRAY) {
        return "array";
    }
    else if (category == STRUCTURE) {
        return "struct";
    }
    else if (category == FUNCTION) {
        return "function";
    }
    else if (category == STRING) {
        return "string";
    }
    else if (category == NUL)
    {
        return "NULL";
    }
    
    return NULL;
}


Category stringToCategory(char* string){
    if (strcmp(string, "int") == 0) {
        return INT;
    }
    if (strcmp(string, "float") == 0) {
        return FLOATNUM;
    }
    if (strcmp(string, "char") == 0) {
        return CHAR;
    }
    if (strcmp(string, "string") == 0) {
        return STRING;
    }
    if (strcmp(string, "bool") == 0) {
        return BOOLEAN;
    }
    if (strcmp(string, "array") == 0) {
        return ARRAY;
    }
    // struct and function
    return 0;
}

void freeTypeTable(TypeTable* typeTable) {
    for (int i = 0; i < TABLE_SIZE; i++) {
        HashNode* currentNode = typeTable -> buckets[i];
        while (currentNode != NULL) {
            HashNode* nextNode = currentNode -> next;
            freeType(currentNode -> type);
            free(currentNode);
            currentNode = nextNode;
        }
    }
    free(typeTable);
}

void freeType(Type* type){
    if (type != NULL){
        if (type -> category == ARRAY){
            freeType(type -> array -> base);
            free(type -> array);
        }else if (type -> category == STRUCTURE){
            if (type -> structure != NULL && type -> structure -> name == NULL) {
                freeTypeList(type -> structure -> typeList);
            }
        }
        else if (type -> category == FUNCTION){
            freeFunction(type -> function);
        } else if (type -> category == NUL){
            printf("warning: Type category is null, name: %s\n", type -> name);
        }
        free(type);
    }
}

void freeCategoryList(CategoryList* categoryList){
    if (categoryList != NULL) {
        freeCategoryList(categoryList -> next);
        free(categoryList);
    }
}

void freeTypeList(TypeList* typeList){
    if (typeList != NULL) {
        freeTypeList(typeList -> next);
        free(typeList);
    }
}

void freeFunction(Function* function){
    if (function != NULL) {
        freeCategoryList(function -> varList);
        free(function);
    }
}