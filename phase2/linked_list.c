#include "linked_list.h"
#include "stdlib.h"

ListNode* createListNode(TreeNode* node) {
    ListNode* newListNode = (ListNode*)malloc(sizeof(ListNode));
    if (newListNode == NULL) {
        printf("内存分配失败\n");
        exit(1);
    }
    newListNode->node = node;
    newListNode->next = NULL;
    return newListNode;
}

void insertListNode(ListNode* head, TreeNode* node) {
    ListNode* newListNode = createListNode(node);
    if (head == NULL) {
        head = newListNode;
    } else {
        ListNode* current = head;
        while (current->next != NULL) {
            current = current->next;
        }
        current->next = newListNode;
    }
}

ListNode* searchListNode(ListNode* head, TreeNode* node) {
    ListNode* current = head;
    while (current != NULL) {
        if (current->node == node) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

void deleteListNode(ListNode* head, TreeNode* node) {
    if (head == NULL) {
        printf("链表为空\n");
        return;
    }
    ListNode* current = head;
    ListNode* prev = NULL;
    while (current != NULL) {
        if (current->node == node) {
            if (prev == NULL) {
                head = current->next;
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

void freeList(ListNode* head) {
    ListNode* current = head;
    ListNode* next;
    while (current != NULL) {
        next = current->next;
        free(current);
        current = next;
    }
    head = NULL;
}