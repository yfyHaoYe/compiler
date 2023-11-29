#ifndef LINKED_LIST
#define LINKED_LIST
#include "tree_node.h"
typedef struct ListNode {
    TreeNode* node;
    struct ListNode* next;
}ListNode;

ListNode* createListNode(TreeNode* node);
void insertListNode(ListNode* head, TreeNode* node);
ListNode* searchListNode(ListNode* head, TreeNode* node);
void deleteListNode(ListNode* head, TreeNode* node);
void freeList(ListNode* head);
#endif