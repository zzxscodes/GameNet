#include "rb_tree.h"

// 红黑树初始化，注意调用完后释放内存rbtree_free()
rbtree *rbtree_init(void){
    rbtree *T = (rbtree*)malloc(sizeof(rbtree));
    if(T == NULL){
        printf("rbtree malloc failed!");
    }else{
        T->nil_node = (rbtree_node*)malloc(sizeof(rbtree_node));
        T->nil_node->color = BLACK;
        T->nil_node->left = T->nil_node;
        T->nil_node->right = T->nil_node;
        T->nil_node->parent = T->nil_node;
        T->root_node = T->nil_node;
    }
    return T;
}

// 红黑树释放内存
void rbtree_destroy(rbtree *T){
    free(T->nil_node);
    free(T);
}

// 在给定节点作为根节点的子树中，找出key最小的节点
rbtree_node* rbtree_min(rbtree *T, rbtree_node *cur){  
    while(cur->left != T->nil_node){
        cur = cur->left;
    }
    return cur;
}

// 在给定节点作为根节点的子树中，找出key最大的节点
rbtree_node* rbtree_max(rbtree *T, rbtree_node *cur){  
    while(cur->right != T->nil_node){
        cur = cur->right;
    }
    return cur;
}

// 找出当前节点的前驱节点
rbtree_node* rbtree_precursor_node(rbtree *T, rbtree_node *cur){
    // 若当前节点有左孩子，那就直接向下找
    if(cur->left != T->nil_node){
        return rbtree_max(T, cur->left);
    }

    // 若当前节点没有左孩子，那就向上找
    rbtree_node *parent = cur->parent;
    while((parent != T->nil_node) && (cur == parent->left)){
        cur = parent;
        parent = cur->parent;
    }
    return parent;
    // 若返回值为空节点，则说明当前节点就是第一个节点
}

// 找出当前节点的后继节点
rbtree_node* rbtree_successor_node(rbtree *T, rbtree_node *cur){
    // 若当前节点有右孩子，那就直接向下找
    if(cur->right != T->nil_node){
        return rbtree_min(T, cur->right);
    }

    // 若当前节点没有右孩子，那就向上找
    rbtree_node *parent = cur->parent;
    while((parent != T->nil_node) && (cur == parent->right)){
        cur = parent;
        parent = cur->parent;
    }
    return parent;
    // 若返回值为空节点，则说明当前节点就是最后一个节点
}

// 红黑树节点左旋，无需修改颜色
void rbtree_left_rotate(rbtree *T, rbtree_node *x){
    // 传入rbtree*是为了判断节点node的左右子树是否为叶子节点、父节点是否为根节点。
    rbtree_node *y = x->right;
    // 注意红黑树中所有路径都是双向的，两边的指针都要改！
    // 另外，按照如下的修改顺序，无需存储额外的节点。
    x->right = y->left;
    if(y->left != T->nil_node){
        y->left->parent = x;
    }

    y->parent = x->parent;
    if(x->parent == T->nil_node){  // x为根节点
        T->root_node = y;
    }else if(x->parent->left == x){
        x->parent->left = y;
    }else{
        x->parent->right = y;
    }

    y->left = x;
    x->parent = y;
}


// 红黑树节点右旋，无需修改颜色
void rbtree_right_rotate(rbtree *T, rbtree_node *y){
    rbtree_node *x = y->left;
    
    y->left = x->right;
    if(x->right != T->nil_node){
        x->right->parent = y;
    }

    x->parent = y->parent;
    if(y->parent == T->nil_node){
        T->root_node = x;
    }else if(y->parent->left == y){
        y->parent->left = x;
    }else{
        y->parent->right = x;
    }

    x->right = y;
    y->parent = x;
}

// 调整插入新节点后的红黑树，使得红色节点不相邻(平衡性)
void rbtree_insert_fixup(rbtree *T, rbtree_node *cur){
    // 父节点是黑色，无需调整。
    // 父节点是红色，则有如下八种情况。
    while(cur->parent->color == RED){
        // 获取叔节点
        rbtree_node *uncle;
        if(cur->parent->parent->left == cur->parent){
            uncle = cur->parent->parent->right;
        }else{
            uncle = cur->parent->parent->left;
        }

        // 若叔节点为红，只需更新颜色(隐含了四种情况)
        // 循环主要在这里起作用
        if(uncle->color == RED){
            // 叔节点为红色：祖父变红/父变黑/叔变黑、祖父节点成新的当前节点。
            if(uncle->color == RED){
                cur->parent->parent->color = RED;
                cur->parent->color = BLACK;
                uncle->color = BLACK;
                cur = cur->parent->parent;
            }
        }
        // 若叔节点为黑，需要变色+旋转(当前节点相当于祖父节点位置包括四种情况:LL/RR/LR/RL)
        // 下面对四种情况进行判断：都是只执行一次
        else{
            if(cur->parent->parent->left == cur->parent){
                // LL：祖父变红/父变黑、祖父右旋。最后的当前节点应该是原来的当前节点。
                if(cur->parent->left == cur){
                    cur->parent->parent->color = RED;
                    cur->parent->color = BLACK;
                    rbtree_right_rotate(T, cur->parent->parent);
                }
                // LR：祖父变红/父变红/当前变黑、父左旋、祖父右旋。最后的当前节点应该是原来的祖父节点。
                else{
                    cur->parent->parent->color = RED;
                    cur->parent->color = RED;
                    cur->color = BLACK;
                    cur = cur->parent;
                    rbtree_left_rotate(T, cur);
                    rbtree_right_rotate(T, cur->parent->parent);
                }
            }
            else{
                // RL：祖父变红/父变红/当前变黑、父右旋、祖父左旋。最后的当前节点应该是原来的祖父节点。
                if(cur->parent->left == cur){
                    cur->parent->parent->color = RED;
                    cur->parent->color = RED;
                    cur->color = BLACK;
                    cur = cur->parent;
                    rbtree_right_rotate(T, cur);
                    rbtree_left_rotate(T, cur->parent->parent);
                }
                // RR：祖父变红/父变黑、祖父左旋。最后的当前节点应该是原来的当前节点。
                else{
                    cur->parent->parent->color = RED;
                    cur->parent->color = BLACK;
                    rbtree_left_rotate(T, cur->parent->parent);
                }
            }
        }
    }
    
    // 将根节点变为黑色
    T->root_node->color = BLACK;
}

// 插入
// void rbtree_insert(rbtree *T, rbtree_node *new){
void rbtree_insert(rbtree *T, KEY_TYPE key, void *value){
    // 创建新节点
    rbtree_node *new = (rbtree_node*)malloc(sizeof(rbtree_node));
    new->key = key;
    new->value = value;
    
    // 寻找插入位置（红黑树中序遍历升序）
    rbtree_node *cur = T->root_node;
    rbtree_node *next = T->root_node;
    // 刚插入的位置一定是叶子节点
    while(next != T->nil_node){
        cur = next;
        if(new->key > cur->key){
            next = cur->right;
        }else if(new->key < cur->key){
            next = cur->left;
        }else if(new->key == cur->key){
            // 红黑树本身没有明确如何处理key相同节点，所以取决于业务。
            // 场景1：统计不同课程的人数，相同就+1。
            // 场景2：时间戳，若相同则稍微加一点
            // 其他场景：覆盖、丢弃...
            printf("Already have the same key=%d!\n", new->key);
            free(new);
            return;
        }
    }
    if(cur == T->nil_node){
        // 若红黑树本身没有节点
        T->root_node = new;
    }else if(new->key > cur->key){
        cur->right = new;
    }else{
        cur->left = new;
    }
    new->parent = cur;
    new->left = T->nil_node;
    new->right = T->nil_node;
    new->color = RED;

    // 调整红黑树，使得红色节点不相邻
    rbtree_insert_fixup(T, new);
}


// 调整删除某节点后的红黑树，使得红色节点不相邻(平衡性)
void rbtree_delete_fixup(rbtree *T, rbtree_node *cur){
    // child是黑色、child不是根节点才会进入循环
    while((cur->color == BLACK) && (cur != T->root_node)){
        // 获取兄弟节点
        rbtree_node *brother = T->nil_node;
        if(cur->parent->left == cur){
            brother = cur->parent->right;
        }else{
            brother = cur->parent->left;
        }
        
        // 兄弟节点为红色：父变红/兄弟变黑、父单旋、当前节点下一循环
        if(brother->color == RED){
            cur->parent->color = RED;
            brother->color = BLACK;
            if(cur->parent->left == cur){
                rbtree_left_rotate(T, cur->parent);
            }else{
                rbtree_right_rotate(T, cur->parent);
            }
        }
        // 兄弟节点为黑色
        else{ 
            // 兄弟节点没有红色子节点：父变黑/兄弟变红、看情况是否结束循环
            if((brother->left->color == BLACK) && (brother->right->color == BLACK)){
                // 若父原先为黑，父节点成新的当前节点进入下一循环；否则结束循环。
                if(brother->parent->color == BLACK){
                    cur = cur->parent;
                }else{
                    cur = T->root_node;
                }
                brother->parent->color = BLACK;
                brother->color = RED;
            }
            // 兄弟节点有红色子节点：LL/LR/RR/RL
            else if(brother->parent->left == brother){
                // LL：红子变黑/兄弟变父色/父变黑、父右旋，结束循环
                if(brother->left->color == RED){
                    brother->left->color = BLACK;
                    brother->color = brother->parent->color;
                    brother->parent->color = BLACK;
                    rbtree_right_rotate(T, brother->parent);
                    cur = T->root_node;
                }
                // LR：红子变父色/父变黑、兄弟左旋/父右旋，结束循环
                else{
                    brother->right->color = brother->parent->color;
                    cur->parent->color = BLACK;
                    rbtree_left_rotate(T, brother);
                    rbtree_right_rotate(T, cur->parent);
                    cur = T->root_node;
                }
            }else{
                // RR：红子变黑/兄弟变父色/父变黑、父左旋，结束循环
                if(brother->right->color == RED){
                    brother->right->color = BLACK;
                    brother->color = brother->parent->color;
                    brother->parent->color = BLACK;
                    rbtree_left_rotate(T, brother->parent);
                    cur = T->root_node;
                }
                // RL：红子变父色/父变黑、兄弟右旋/父左旋，结束循环
                else{
                    brother->left->color = brother->parent->color;
                    brother->parent->color = BLACK;
                    rbtree_right_rotate(T, brother);
                    rbtree_left_rotate(T, cur->parent);
                    cur = T->root_node;
                }
            }
        }
    }
    // 下面这行处理情况2/3
    cur->color = BLACK;
}

// 红黑树删除
void rbtree_delete(rbtree *T, rbtree_node *del){
    if(del != T->nil_node){
        /* 红黑树删除逻辑：
            1. 标准的BST删除操作(本函数)：最红都会转换成删除只有一个子节点或者没有子节点的节点。
            2. 若删除节点为黑色，则进行调整(rebtre_delete_fixup)。
        */
        rbtree_node *del_r = T->nil_node;        // 实际删除的节点
        rbtree_node *del_r_child = T->nil_node;  // 实际删除节点的子节点

        // 找出实际删除的节点
        // 注：实际删除的节点最多只有一个子节点，或者没有子节点(必然在最后两层中，不包括叶子节点那一层)
        if((del->left == T->nil_node) || (del->right == T->nil_node)){
            // 如果要删除的节点本身就只有一个孩子或者没有孩子，那实际删除的节点就是该节点
            del_r = del;
        }else{
            // 如果要删除的节点有两个孩子，那就使用其后继节点(必然最多只有一个孩子)
            del_r = rbtree_successor_node(T, del);
        }

        // 看看删除节点的孩子是谁，没有孩子就是空节点
        if(del_r->left != T->nil_node){
            del_r_child = del_r->left;
        }else{
            del_r_child = del_r->right;
        }

        // 将实际要删除的节点删除
        del_r_child->parent = del_r->parent;  // 若child为空节点，最后再把父节点指向空节点
        if(del_r->parent == T->nil_node){
            T->root_node = del_r_child;
        }else if(del_r->parent->left == del_r){
            del_r->parent->left = del_r_child;
        }else{
            del_r->parent->right = del_r_child;
        }

        // 替换替换键值对
        if(del != del_r){
            del->key = del_r->key;
            del->value = del_r->value;
        }

        // 最后看是否需要调整
        if(del_r->color == BLACK){
            rbtree_delete_fixup(T, del_r_child);
        }
        
        // 调整空节点的父节点
        if(del_r_child == T->nil_node){
            del_r_child->parent = T->nil_node;
        }
        free(del_r);
    }
}

// 查找
rbtree_node* rbtree_search(rbtree *T, KEY_TYPE key){
    rbtree_node *cur = T->root_node;
    while(cur != T->nil_node){
        if(cur->key > key){
            cur = cur->left;
        }else if(cur->key < key){
            cur = cur->right;
        }else{
            return cur;
        }
    }
    printf("There is NO key=%d in rbtree!\n", key);
    return T->nil_node;
}

// 中序遍历给定结点为根节点的子树（递归）
void rbtree_traversal_node(rbtree *T, rbtree_node *cur){
    if(cur != T->nil_node){
        rbtree_traversal_node(T, cur->left);
        if(cur->color == RED){
            printf("Key:%d\tColor:Red\n", cur->key);
        }else{
            printf("Key:%d\tColor:Black\n", cur->key);
        }
        rbtree_traversal_node(T, cur->right);
    }
}

// 中序遍历整个红黑树
void rbtree_traversal(rbtree *T){
    rbtree_traversal_node(T, T->root_node);
}

// 递归计算红黑树的深度（不包括叶子节点）
int rbtree_depth_recursion(rbtree *T, rbtree_node *cur){
    if(cur == T->nil_node){
        return 0;
    }else{
        int left = rbtree_depth_recursion(T, cur->left);
        int right = rbtree_depth_recursion(T, cur->right);
        return ((left > right) ? left : right) + 1;
    }
}

// 计算红黑树的深度
int rbtree_depth(rbtree *T){
    return rbtree_depth_recursion(T, T->root_node);
}

// 获取输入数字的十进制显示宽度
int decimal_width(int num_in){
    int width = 0;
    while (num_in != 0){
        num_in = num_in / 10;
        width++;
    }
    return width;
}

// 先序遍历，打印红黑树信息到字符数组指针
void set_display_buffer(rbtree *T, rbtree_node *cur, disp_parameters *p){
    if(cur != T->nil_node){
        // 输出当前节点
        p->disp_depth++;
        // 输出数字到缓冲区
        char num_char[20];
        char formatString[20];
        int cur_num_width = decimal_width(cur->key);
        int num_space = (p->node_width - 2 - cur_num_width) >> 1;  // 数字后面需要补充的空格数量
        strncpy(formatString, "|%*d", sizeof(formatString));
        int i = 0;
        for(i=0; i<num_space; i++){
            strncat(formatString, " ", 2);
        }
        strncat(formatString, "|", 2);
        snprintf(num_char, sizeof(num_char), formatString, (p->node_width-2-num_space), cur->key);
        i = 0;
        while(num_char[i] != '\0'){
            p->disp_buffer[(p->disp_depth-1)*3][p->disp_column+i] = num_char[i];
            i++;
        }
        // 输出颜色到缓冲区
        char color_char[20];
        if(cur->color == RED){
            num_space = (p->node_width-2-3)>>1;
            strncpy(color_char, "|", 2);
            for(i=0; i<(p->node_width-2-3-num_space); i++){
                strncat(color_char, " ", 2);
            }
            strncat(color_char, "RED", 4);
            for(i=0; i<num_space; i++){
                strncat(color_char, " ", 2);
            }
            strncat(color_char, "|", 2);
        }else{
            num_space = (p->node_width-2-5)>>1;
            strncpy(color_char, "|", 2);
            for(i=0; i<(p->node_width-2-5-num_space); i++){
                strncat(color_char, " ", 2);
            }
            strncat(color_char, "BLACK", 6);
            for(i=0; i<num_space; i++){
                strncat(color_char, " ", 2);
            }
            strncat(color_char, "|", 2);
        }
        // strcpy(color_char, (cur->color == RED) ? "| RED |" : "|BLACK|");
        i = 0;
        while(color_char[i] != '\0'){
            p->disp_buffer[(p->disp_depth-1)*3+1][p->disp_column+i] = color_char[i];
            i++;
        }
        // 输出连接符到缓冲区
        if(p->disp_depth>1){
            char connector_char[10];
            strcpy(connector_char, (cur->parent->left == cur) ? "/" : "\\");
            p->disp_buffer[(p->disp_depth-1)*3-1][p->disp_column+(p->node_width>>1)] = connector_char[0];
        }

        // 下一层需要前进/后退的字符数
        int steps = 0;
        if(p->disp_depth+1 == p->max_depth){
            steps = (p->node_width>>1)+1;
        }else{
            steps = (1<<(p->max_depth - p->disp_depth - 2)) * p->node_width;
        }

        // 输出左侧节点
        p->disp_column -= steps;
        set_display_buffer(T, cur->left, p);
        p->disp_column += steps;
        
        // 输出右侧节点
        if(p->disp_depth+1 == p->max_depth){
            steps = p->node_width-steps;
        }
        p->disp_column += steps;
        set_display_buffer(T, cur->right, p);
        p->disp_column -= steps;
        
        p->disp_depth--;
    }
}

// 以图的形式展示红黑树
void rbtree_display(rbtree *T){
    // 红黑树为空不画图
    if(T->root_node == T->nil_node){
        printf("rbtree DO NOT have any key!\n");
        return;
    }

    // 初始化参数结构体
    disp_parameters *para = (disp_parameters*)malloc(sizeof(disp_parameters));
    if(para == NULL){
        printf("disp_parameters struct malloc failed!");
        return;
    }
    rbtree_node *max_node = rbtree_max(T, T->root_node);
    para->max_num_width = decimal_width(max_node->key);    
    para->max_depth = rbtree_depth(T);
    para->node_width = (para->max_num_width<=5) ? 7 : (para->max_num_width+2);  // 边框“||”宽度2 + 数字宽度
    para->disp_depth = 0;
    para->disp_width = para->node_width * (1 << (para->max_depth-1)) + 1;
    para->disp_column = ((para->disp_width-para->node_width)>>1);
    int height = (para->max_depth-1)*3 + 2;
    // 根据树的大小申请内存
    para->disp_buffer = (char**)malloc(sizeof(char*)*height);
    int i = 0;
    for(i=0; i<height; i++){
        para->disp_buffer[i] = (char*)malloc(sizeof(char)*para->disp_width);
        memset(para->disp_buffer[i], ' ', para->disp_width);
        para->disp_buffer[i][para->disp_width-1] = '\0';
    }

    // 打印内容
    set_display_buffer(T, T->root_node, para);
    for(i=0; i<height; i++){
        printf("%s\n", para->disp_buffer[i]);
    }

    // 释放内存
    for(i=0; i<height; i++){
        free(para->disp_buffer[i]);
    }
    free(para->disp_buffer);
    free(para);
}


// 检查当前红黑树的有效性：根节点黑色、红色不相邻、所有路径黑高相同
bool rbtree_check_effective(rbtree *T){
    bool rc_flag = true;  // 根节点黑色
    bool rn_flag = true;  // 红色不相邻
    bool bh_flag = true;  // 所有路径黑高相同
    if(T->root_node->color == RED){
        printf("ERROR! root-node's color is RED!\n");
        rc_flag = false;
    }else{
        int depth = rbtree_depth(T);
        int max_index_path = 1<<(depth-1);  // 从根节点出发的路径总数
        // 获取最左侧路径的黑高
        int black_height = 0;
        rbtree_node *cur = T->root_node;
        while(cur != T->nil_node){
            if(cur->color == BLACK) black_height++;
            cur = cur->left;
            // printf("bh = %d\n", black_height);
        }
        // 遍历每一条路径
        int i_path = 0;
        for(i_path=1; i_path<max_index_path; i_path++){
            int dir = i_path;
            int bh = 0;  // 当前路径的黑高
            cur = T->root_node;
            while(cur != T->nil_node){
                // 更新黑高
                if(cur->color == BLACK){
                    bh++;
                }
                // 判断红色节点不相邻
                else{
                    if((cur->left->color == RED) || (cur->right->color == RED)){
                        printf("ERROR! red node %d has red child!\n", cur->key);
                        rn_flag = false;
                    }
                }
                // 更新下一节点
                // 0:left, 1:right
                if(dir%2) cur = cur->right;
                else      cur = cur->left;
                dir = dir>>1;
            }
            if(bh != black_height){
                printf("ERROR! black height is not same! path 0 is %d, path %d is %d.\n", black_height, i_path, bh);
                bh_flag = false;
            }
        }
    }
    return (rc_flag && rn_flag && bh_flag);
}