#!/bin/bash

set -e
mkdir -p /runner/work/cache

# perl cache
cd /runner/work/cache
if [ ! -e perl ]; then cpanm --notest Test::Nginx Protocol::WebSocket > build.log 2>&1 || (cat build.log && exit 1); cp -r /usr/local/share/perl/ .; else cp -r perl /usr/local/share; fi

# build tools at parent directory of cache
cd /runner/work
git clone https://github.com/openresty/openresty.git ./openresty
git clone https://github.com/openresty/nginx-devel-utils.git
git clone https://github.com/simpl/ngx_devel_kit.git ./ndk-nginx-module
git clone https://github.com/openresty/lua-nginx-module.git ./lua-nginx-module -b ${VAR_LUA_NGINX_MODULE}
git clone https://github.com/openresty/stream-lua-nginx-module.git ./stream-lua-nginx-module -b ${VAR_STREAM_LUA_NGINX_MODULE}
git clone https://github.com/openresty/no-pool-nginx.git ./no-pool-nginx

# lua libraries at parent directory of current repository
mkdir $LUAJIT_LIB
git clone https://github.com/openresty/lua-resty-core.git ../lua-resty-core -b ${VAR_LUA_RESTY_CORE}
git clone https://github.com/openresty/lua-resty-lrucache.git ../lua-resty-lrucache
git clone -b v0.15 https://github.com/ledgetech/lua-resty-http ../lua-resty-http

cp -r "../lua-resty-lrucache/lib/"* "../lib/"
cp -r "../lua-resty-http/lib/"* "../lib/"
find ../lib


