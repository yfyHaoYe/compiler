#ifndef LINKED_LIST
#define LINKED_LIST
typedef struct ListNode {
    char arg[20];
    struct ListNode* next;
}ListNode;

ListNode* createListNode(const char* arg);
void insertListNode(ListNode** head, const char* arg);
ListNode* searchListNode(ListNode** head, const char* arg);
void deleteListNode(ListNode** head, const char* arg);
void freeList(ListNode** head);
#endif