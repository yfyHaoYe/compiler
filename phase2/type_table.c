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

HashNode* createHashNode(char* name, Type* type){
    HashNode* node = (HashNode*)malloc(sizeof(HashNode));
    node->name = name;
    node->type = type;
    node->next = NULL;
    return node;
}

int insertIntoTypeTable(TypeTable* typeTable, char* name, Type* type){
    unsigned int hash = hashFunction(name);   
    HashNode* node = createHashNode(name, type);
    HashNode* currentNode = typeTable->buckets[hash];
    int isFilled = typeTable->isFilled[hash];    
    if(isFilled == 1){
        while(currentNode->next != NULL){
            if (strcmp(currentNode->name, name) == 0) {
                return 1;
            }
            currentNode = currentNode->next;
        }
        currentNode->next = node;
    }else{
        typeTable->isFilled[hash] = 1;
        typeTable->buckets[hash] = node;
    }
    return 0;
}

bool isContains(TypeTable* typeTable, char* name){
    unsigned int hash = hashFunction(name);
    HashNode* currentNode = typeTable->buckets[hash];
    int isFilled = typeTable->isFilled[hash];
    if(isFilled == 1){
        while(currentNode != NULL){
            if (strcmp(currentNode->name, name) == 0) {
                return true;
            }
            currentNode = currentNode->next;
        }
    }
    return false;
}

HashNode* getValuesFromTypeTable(TypeTable* typeTable, char* name) {
    unsigned int hash = hashFunction(name);
    HashNode* currentNode = typeTable->buckets[hash];

    while (currentNode != NULL) {
        if (strcmp(currentNode->name, name) == 0) {
            return currentNode;
        }
        currentNode = currentNode->next;
    }

    return NULL;
}


void freeTypeTable(TypeTable* typeTable) {
    for (int i = 0; i < TABLE_SIZE; i++) {
        HashNode* currentNode = typeTable->buckets[i];
        while (currentNode != NULL) {
            HashNode* nextNode = currentNode->next;
            free(currentNode->name);
            free(currentNode);
            currentNode = nextNode;
        }
    }
}