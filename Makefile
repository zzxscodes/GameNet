PLAT ?= linux
CC ?= gcc

.PHONY : clean gamenet linux all luajit cleanall
.PHONY : default

default :
	$(MAKE) all

LUA_CLIB_PATH ?= luaclib
LUA_CLIB_SRC ?= lualib-src
LUA_CLIB ?= gamenet
LUA_INC_PATH ?= deps/luajit2/src
gamenet_LIBS ?= -ldl -lm
CORE_PATH ?= ./core

linux : PLAT := linux

SHARED = -fPIC --shared
EXPORT = -Wl,-E

LUAJIT_STATICLIB := deps/luajit2/src/libluajit.a

MACOSX_DEPLOYMENT_TARGET :=

XCFLAGS := '-DLUAJIT_ENABLE_LUA52COMPAT -fno-stack-check'

luajit :
	cd deps/luajit2 && \
	$(MAKE) CC=$(CC) XCFLAGS=$(XCFLAGS) MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)

LUA_CLIB_gamenet = \
	lua-ae.c \
	lua-anet.c \
	lua-core.c lsha1.c\
	lua-buffer.c \
	lua_rbtree.c \
	lua_dhash.c

CFLAGS = -g -O2 -Wall -I$(LUA_INC_PATH)

NET_SRC = ae.c anet.c systime.c buffer.c gamenet.c rb_tree.c dhash.c

all : \
	luajit \
	gamenet \
	$(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)

gamenet : $(foreach v, $(NET_SRC), $(CORE_PATH)/$(v)) $(LUAJIT_STATICLIB) 
	$(CC) $(CFLAGS) $^ -o $@ -I$(LUA_INC_PATH) $(EXPORT) $(gamenet_LIBS) $(gamenet_DEFINE)

$(LUA_CLIB_PATH) :
	mkdir -p $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/gamenet.so : $(addprefix lualib-src/,$(LUA_CLIB_gamenet)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(LUA_INC_PATH) -I$(CORE_PATH) -I$(LUA_CLIB_SRC)

clean:
	rm -f gamenet && \
    rm -rf $(LUA_CLIB_PATH)

cleanall: clean
	cd deps/luajit2 && $(MAKE) clean MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
	rm -f $(LUAJIT_STATICLIB)
