#include "type_table.h"
#include <stdlib.h>
#include<stdio.h>
#include<stdbool.h>

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

bool insertIntoTypeTable(TypeTable* typeTable, Type* type){
    unsigned int hash = hashFunction(type -> name);
    HashNode* node = createHashNode(type);
    if (!typeTable -> isFilled[hash]) {
        typeTable -> isFilled[hash] = 1;
        typeTable -> buckets[hash] = node;
        return true;
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
    for (int i=0; i < TABLE_SIZE; i++){
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
    char* category;
    if (type -> category == INT) {
        category = "int";
    }
    else if (type -> category == FLOATE) {
        category = "float";
    }
    else if (type -> category == CHAR) {
        category = "char";
    }
    else if (type -> category == ARRAY) {
        category = "array";
    }
    else if (type -> category == STRUCTURE) {
        category = "structure";
    }
    else if (type -> category == FUNCTION) {
        category = "function";
    }
    printf("Type name: %s, category: %s\n", type -> name, category);
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
}

void freeType(Type* type){
    if (type -> category == ARRAY){
        freeType(type -> array -> base);
        free(type -> array);
    }
    else if (type -> category == STRUCTURE){
        freeTypeList(type -> structure);
    }
    else if (type -> category == FUNCTION){
        freeFunction(type -> function);
    } else {
        printf("Type category is null, name:%s\n, find in freeType", type -> name);
    }
    free(type);
}

void freeTypeList(TypeList* typeList){
    freeType(typeList -> type);
    freeTypeList(typeList -> next);
    free(typeList);
}

void freeFunction(Function* function){
    freeType(function -> returnType);
    freeTypeList(function -> varList);
    free(function);
}