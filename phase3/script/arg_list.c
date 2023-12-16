#include "arg_list.h"
#include <stdlib.h>
#include <stdio.h>
ListNode* createListNode(const char* arg) {
    ListNode* newListNode = (ListNode*)malloc(sizeof(ListNode));
    if (newListNode == NULL) {
        printf("内存分配失败\n");
        exit(1);
    }
    strcpy(newListNode->arg, arg);
    newListNode->next = NULL;
    return newListNode;
}

void insertListNode(ListNode** head, const char* arg) {
    ListNode* newListNode = createListNode(arg);
    if (*head == NULL) {
        *head = newListNode;
    } else {
        ListNode* current = *head;
        while (current->next != NULL) {
            current = current->next;
        }
        current->next = newListNode;
    }
}

ListNode* searchListNode(ListNode** head, const char* arg) {
    ListNode* current = *head;
    while (current != NULL) {
        if (strcmp(current->arg, arg)) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

void deleteListNode(ListNode** head, const char* arg) {
    if (*head == NULL) {
        printf("链表为空\n");
        return;
    }
    ListNode* current = *head;
    ListNode* prev = NULL;
    while (current != NULL) {
        if (strcmp(current->arg, arg)) {
            if (prev == NULL) {
                *head = current->next;
            } else {
                prev->next = current->next;
            }
            free(current);
            printf("节点删除成功\n");
            return;
        }
        prev = current;
        current = current->next;
    }
    printf("节点未找到\n");
}

void freeList(ListNode** head) {
    ListNode* current = *head;
    ListNode* next;
    while (current != NULL) {
        next = current->next;
        free(current);
        current = next;
    }
    *head = NULL;
    free(head);
}