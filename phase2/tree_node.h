// tree_node.h
#ifndef TREE_NODE_H
#define TREE_NODE_H
#include <stdbool.h>
typedef struct TreeNode {
    char* type;
    char* value;
    int line;
    bool empty;
    struct TreeNode** children;
    int numChildren;
} TreeNode;

#endif
