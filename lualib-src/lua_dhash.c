#include <lua.h>
#include <lauxlib.h>
#include "dhash.h"

static int
ldhash_insert(lua_State *L) {
    dhash_table_t *table = (dhash_table_t *)luaL_checkudata(L, 1, "gamenet.dhash");
    DH_KEY_TYPE key = (DH_KEY_TYPE)luaL_checkinteger(L, 2);
    DH_VALUE_TYPE value = (DH_VALUE_TYPE)luaL_checkinteger(L, 3);
    int result = dhash_node_insert(table, key, value);
    lua_pushinteger(L, result);
    return 1;
}

static int
ldhash_delete(lua_State *L) {
    dhash_table_t *table = (dhash_table_t *)luaL_checkudata(L, 1, "gamenet.dhash");
    DH_KEY_TYPE key = (DH_KEY_TYPE)luaL_checkinteger(L, 2);
    int result = dhash_node_delete(table, key);
    lua_pushinteger(L, result);
    return 1;
}

static int
ldhash_search(lua_State *L) {
    dhash_table_t *table = (dhash_table_t *)luaL_checkudata(L, 1, "gamenet.dhash");
    DH_KEY_TYPE key = (DH_KEY_TYPE)luaL_checkinteger(L, 2);
    int index = dhash_node_search(table, key);
    if (index >= 0) {
        lua_pushinteger(L, (lua_Integer)table->nodes[index]->value);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int
ldhash_destroy(lua_State *L) {
    dhash_table_t *table = (dhash_table_t *)luaL_checkudata(L, 1, "gamenet.dhash");
    int result = dhash_table_destroy(table);
    lua_pushinteger(L, result);
    return 1;
}

static int
ldhash_new(lua_State *L) {
    int size = luaL_checkinteger(L, 1);
    dhash_table_t *table = (dhash_table_t *)lua_newuserdata(L, sizeof(dhash_table_t));
    int result = dhash_table_init(table, size);
    if (result != 0) {
        lua_pushnil(L);
        lua_pushstring(L, "Failed to initialize dhash table");
        return 2;
    }
    if (luaL_newmetatable(L, "gamenet.dhash")) {
        luaL_Reg m[] = {
            {"insert", ldhash_insert},
            {"delete", ldhash_delete},
            {"search", ldhash_search},
            {"destroy", ldhash_destroy},
            {NULL, NULL},
        };
        luaL_newlib(L, m);
        lua_setfield(L, -2, "__index");
    }
    lua_setmetatable(L, -2);
    return 1;
}

static const luaL_Reg lib[] = {
    {"new", ldhash_new},
    {NULL, NULL},
};

int luaopen_gamenet_dhash(lua_State *L) {
    luaL_newlib(L, lib);
    return 1;
}
