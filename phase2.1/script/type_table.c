#include "type_table.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>

#include "my_print.c"

unsigned int hashFunction(char* name){
    unsigned int hash = 0;
    unsigned int i;
    unsigned int len = strlen(name);
    for (i = 0; i < len; i++) {
        hash = (hash << 5) + name[i];
    }
    return hash % TABLE_SIZE;
}

HashNode* createHashNode(Type* type){
    HashNode* node = (HashNode*)malloc(sizeof(HashNode));
    node->type = type;
    node->next = NULL;
    return node;
}

bool insertIntoTypeTable(TypeTable* typeTable, Type* type, int line){
    unsigned int hash = hashFunction(type -> name);
    HashNode* node = createHashNode(type);
    if (!typeTable -> isFilled[hash]) {
        typeTable -> isFilled[hash] = 1;
        typeTable -> buckets[hash] = node;
        my_print(INFO, "info line %d: success inserted! name: %s, category: %s\n", line, type -> name, categoryToString(type -> category));
        return true;
    }else{
        my_print(ERROR, "redeclaring\n");
    }

    HashNode* currentNode = typeTable -> buckets[hash];
    HashNode* pre;
    while(currentNode != NULL){
        pre = currentNode;
        currentNode = currentNode -> next;
    }
    pre -> next = node;
    return true;
}

bool contain(TypeTable* typeTable, char* name){
    my_print(INFO, "why?\n");
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
        return checkStructureSame(type1 -> structure, type2 -> structure);
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
    printf("\n");
}

void printType(Type* type){
    char* categoryName = categoryToString(type -> category);
    printf("Type name: %s, category: %s\n", type -> name, categoryName);
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
        return "structure";
    }
    else if (category == FUNCTION) {
        return "function";
    }
    else if (category == STRING) {
        return "string";
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

void freeTypeTable(int line, TypeTable* typeTable) {
    for (int i = 0; i < TABLE_SIZE; i++) {
        HashNode* currentNode = typeTable -> buckets[i];
        while (currentNode != NULL) {
            HashNode* nextNode = currentNode -> next;
            freeType(line, currentNode -> type);
            free(currentNode);
            currentNode = nextNode;
        }
    }
}

void freeType(int line, Type* type){
    if (type -> category == ARRAY){
        freeType(line, type -> array -> base);
        free(type -> array);
    }
    else if (type -> category == STRUCTURE){
        freeTypeList(line, type -> structure);
    }
    else if (type -> category == FUNCTION){
        freeFunction(line, type -> function);
    } else if (type -> category == 0){
        my_print(WARNING, "warning line %d: Type category is null, name:%s\n", line, type -> name);
    }
    free(type);
}

void freeTypeList(int line, TypeList* typeList){
    freeType(line, typeList -> type);
    freeTypeList(line, typeList -> next);
    free(typeList);
}

void freeFunction(int line, Function* function){
    freeTypeList(line, function -> varList);
    free(function);
}