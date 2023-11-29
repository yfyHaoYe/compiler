#include "type_table.h"
#include <stdlib.h>
#include<stdio.h>

unsigned int hashFunction(const char* name){
    unsigned int hash = 0;
    unsigned int i;
    unsigned int len = strlen(name);
    for (i = 0; i < len; i++) {
        hash = (hash << 5) + name[i];
    }
    return hash % TABLE_SIZE;
}

HashNode* createHashNode(const char* name, Type* type){
    HashNode* node = (HashNode*)malloc(sizeof(HashNode));
    strcpy(node->name, name);
    node->type = type;
    node->next = NULL;
}

void insertIntoTypeTable(TypeTable* typeTable, const char* name, Type* type){
    unsigned int hash = hashFunction(name);
    HashNode* node = createHashNode(name, type);
    HashNode* currentNode = typeTable->buckets[hash];
    while(currentNode != NULL){
        if (strcmp(currentNode->name, name) == 0) {
            /* HashNode* newValueNode = node;
            newValueNode->next = currentNode->next;
            currentNode->next = newValueNode; */
            printf("duplicated specifier\n");
            return;
        }
        currentNode = currentNode->next;
    }
    typeTable->buckets[hash] = node;
}

HashNode* getValuesFromTypeTable(TypeTable* typeTable, const char* name) {
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