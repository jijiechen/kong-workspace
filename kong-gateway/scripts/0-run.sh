#!/bin/bash

cd /runner/work/

export PATH=$BASE_PATH/work/nginx/sbin:$BASE_PATH/../nginx-devel-utils:$PATH
export LD_LIBRARY_PATH=$LUAJIT_LIB:$PWD/mockeagain:$LD_LIBRARY_PATH
export LD_PRELOAD=$PWD/mockeagain/mockeagain.so


# export TEST_NGINX_RESOLVER=8.8.4.4

cp -r /runner/work/code/* ./
prove -I. -j$JOBS -r /runner/work/t/