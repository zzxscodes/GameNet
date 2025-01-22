#ifndef _DHASH_H
#define _DHASH_H

// 键值对类型
// 独热码：注意下面只能选一个！！！
#define KV_DHTYPE_INT_INT    0    // int key, int value
#define KV_DHTYPE_CHAR_CHAR  1    // char* key, char* value
#define DHASH_INIT_TABLE_SIZE   512   // 动态哈希表的初始长度
#define DHASH_GROW_FACTOR       2     // 动态哈希表的扩展倍数

// 定义键值对的类型
#if KV_DHTYPE_INT_INT
    typedef int  DH_KEY_TYPE;   // key类型
    typedef int  DH_VALUE_TYPE; // value类型
#elif KV_DHTYPE_CHAR_CHAR
    typedef char* DH_KEY_TYPE;    // key类型
    typedef char* DH_VALUE_TYPE;  // value类型
#endif

// 单个哈希节点定义
typedef struct dhash_node_s {
    DH_KEY_TYPE key;
    DH_VALUE_TYPE value;
} dhash_node_t;

// 哈希表结构体
typedef struct dhash_table_s {
    struct dhash_node_s** nodes; // 哈希表头
    int max_size;   // 哈希表的最大容量
    int count;      // 哈希表中存储的元素总数
} dhash_table_t;
typedef dhash_table_t kv_dhash_t;

int dhash_function(DH_KEY_TYPE key, int size);
dhash_node_t* dhash_node_create(DH_KEY_TYPE key, DH_KEY_TYPE value);
int dhash_node_desy(dhash_node_t* node);
int dhash_table_init(dhash_table_t* dhash, int size);
int dhash_table_destroy(dhash_table_t* dhash);
int dhash_node_insert(dhash_table_t *dhash, DH_KEY_TYPE key, DH_KEY_TYPE value);
int dhash_node_search(dhash_table_t* dhash, DH_KEY_TYPE key);
int dhash_node_delete(dhash_table_t* dhash, DH_KEY_TYPE key);
int dhash_table_print(dhash_table_t* dhash);

#endif // _DHASH_H