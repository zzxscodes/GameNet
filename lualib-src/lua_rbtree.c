#include <lua.h>
#include <lauxlib.h>
#include "rb_tree.h"

static int
lrbtree_insert(lua_State *L) {
    rbtree *tree = (rbtree *)luaL_checkudata(L, 1, "gamenet.rbtree");
    int key = luaL_checkinteger(L, 2);
    void *value = (void *)luaL_checkstring(L, 3);
    rbtree_insert(tree, key, value);
    return 0;
}

static int
lrbtree_delete(lua_State *L) {
    rbtree *tree = (rbtree *)luaL_checkudata(L, 1, "gamenet.rbtree");
    int key = luaL_checkinteger(L, 2);
    rbtree_node *node = rbtree_search(tree, key);
    if (node != tree->nil_node) {
        rbtree_delete(tree, node);
    }
    return 0;
}

static int
lrbtree_search(lua_State *L) {
    rbtree *tree = (rbtree *)luaL_checkudata(L, 1, "gamenet.rbtree");
    int key = luaL_checkinteger(L, 2);
    rbtree_node *node = rbtree_search(tree, key);
    if (node != tree->nil_node) {
        lua_pushstring(L, (const char *)node->value);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int
lrbtree_destroy(lua_State *L) {
    rbtree *tree = (rbtree *)luaL_checkudata(L, 1, "gamenet.rbtree");
    rbtree_destroy(tree);
    return 0;
}

static int
lrbtree_new(lua_State *L) {
    rbtree *tree = (rbtree *)lua_newuserdata(L, sizeof(rbtree));
    *tree = *rbtree_init();
    if (luaL_newmetatable(L, "gamenet.rbtree")) {
        luaL_Reg m[] = {
            {"insert", lrbtree_insert},
            {"delete", lrbtree_delete},
            {"search", lrbtree_search},
            {"destroy", lrbtree_destroy},
            {NULL, NULL},
        };
        luaL_newlib(L, m);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}

static const luaL_Reg lib[] = {
    {"new", lrbtree_new},
    {NULL, NULL},
};

int luaopen_gamenet_rbtree(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}
