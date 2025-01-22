#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<stdbool.h>

// 本代码实现红黑树，存储int型key，未指定value。

typedef int KEY_TYPE;  // 节点的key类型
#define RED   1
#define BLACK 0

// 定义红黑树单独节点
typedef struct _rbtree_node {
    KEY_TYPE key;      // 键
    void *value;  // 值，可以指向任何类型
    struct _rbtree_node *left;
    struct _rbtree_node *right;
    struct _rbtree_node *parent;
    unsigned char color;  // 不同编译器的无符号性质符号不同，这里加上unsigned减少意外。
    /* 对于32位系统，上述只有color是1个字节，其余都是4个字节，所以color放在最后可以节省内存。 */
} rbtree_node;

// 定义整个红黑树
typedef struct _rbtree{
    struct _rbtree_node *root_node; // 根节点
    struct _rbtree_node *nil_node; // 空节点，也就是叶子节点、根节点的父节点
} rbtree;

// 存储打印红黑树所需的参数
typedef struct _disp_parameters{
    // 打印缓冲区
    char **disp_buffer;
    // 打印缓冲区的深度，宽度，当前打印的列数
    int disp_depth;
    int disp_width;
    int disp_column;
    // 树的深度
    int max_depth;
    // 最大的数字位宽
    int max_num_width;
    // 单个节点的显示宽度
    int node_width;
}disp_parameters;


/*----初始化及释放内存----*/
// 红黑树初始化，注意调用完后释放内存rbtree_free
rbtree *rbtree_init(void);
// 红黑树释放内存
void rbtree_destroy(rbtree *T);

/*----插入操作----*/
// 红黑树插入
void rbtree_insert(rbtree *T, KEY_TYPE key, void *value);
// 调整插入新节点后的红黑树，使得红色节点不相邻(平衡性)
void rbtree_insert_fixup(rbtree *T, rbtree_node *cur);

/*----删除操作----*/
// 红黑树删除
void rbtree_delete(rbtree *T, rbtree_node *del);
// 调整删除某节点后的红黑树，使得红色节点不相邻(平衡性)
void rbtree_delete_fixup(rbtree *T, rbtree_node *cur);

/*----查找操作----*/
// 红黑树查找
rbtree_node* rbtree_search(rbtree *T, KEY_TYPE key);

/*----打印信息----*/
// 中序遍历整个红黑树，依次打印节点信息
void rbtree_traversal(rbtree *T);
// 以图的形式展示红黑树
void rbtree_display(rbtree *T);
// 先序遍历，打印红黑树信息到字符数组指针
void set_display_buffer(rbtree *T, rbtree_node *cur, disp_parameters *p);

/*----检查有效性----*/
// 检查当前红黑树的有效性：根节点黑色、红色不相邻、所有路径黑高相同
bool rbtree_check_effective(rbtree *T);

/*----其他函数----*/
// 在给定节点作为根节点的子树中，找出key最小的节点
rbtree_node* rbtree_min(rbtree *T, rbtree_node *cur);
// 在给定节点作为根节点的子树中，找出key最大的节点
rbtree_node* rbtree_max(rbtree *T, rbtree_node *cur);
// 找出当前节点的前驱节点
rbtree_node* rbtree_precursor_node(rbtree *T, rbtree_node *cur);
// 找出当前节点的后继节点
rbtree_node* rbtree_successor_node(rbtree *T, rbtree_node *cur);
// 红黑树节点左旋，无需修改颜色
void rbtree_left_rotate(rbtree *T, rbtree_node *x);
// 红黑树节点右旋，无需修改颜色
void rbtree_right_rotate(rbtree *T, rbtree_node *y);
// 计算红黑树的深度
int rbtree_depth(rbtree *T);
// 递归计算红黑树的深度（不包括叶子节点）
int rbtree_depth_recursion(rbtree *T, rbtree_node *cur);