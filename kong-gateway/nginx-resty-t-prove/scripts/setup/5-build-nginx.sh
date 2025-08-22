#!/bin/bash

set -e
cd $BASE_PATH

export PATH=$BASE_PATH/work/nginx/sbin:$BASE_PATH/../nginx-devel-utils:$PATH
export LD_LIBRARY_PATH=$LUAJIT_LIB:$LD_LIBRARY_PATH

if [ ! -e work ]; then ngx-build ${VAR_NGINX} --add-module=../ndk-nginx-module --add-module=../lua-nginx-module --add-module=../stream-lua-nginx-module --with-http_ssl_module --with-stream --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt="-I$OPENSSL_INC $NGINX_CC_OPTS" --with-ld-opt="-L$OPENSSL_LIB -Wl,-rpath,$OPENSSL_LIB" --with-debug > build.log 2>&1 || (cat build.log && exit 1); fi
nginx -V
ldd `which nginx`|grep -E 'luajit|ssl|pcre'