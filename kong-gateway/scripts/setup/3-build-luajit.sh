#!/bin/bash

set -e

mkdir -p $LUAJIT_PREFIX
cd $LUAJIT_PREFIX

if [ ! -e luajit2 ]; then git clone -b v2.1-agentzh https://github.com/openresty/luajit2.git; fi
cd luajit2
make -j$JOBS CCDEBUG=-g Q= PREFIX=$LUAJIT_PREFIX CC=$CC XCFLAGS="-DLUA_USE_APICHECK -DLUA_USE_ASSERT -DLUAJIT_ENABLE_LUA52COMPAT $LUAJIT_CC_OPTS" > build.log 2>&1 || (cat build.log && exit 1)
make install PREFIX=$LUAJIT_PREFIX > build.log 2>&1 || (cat build.log && exit 1)