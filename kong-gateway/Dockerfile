
FROM ubuntu:22.04


ENV VAR_NGINX=1.21.4
ENV VAR_OPENSSL=1.1.1s
# becasue tagging error on openresty, we use master temporarily
# lua_nginx_module: "v0.10.22"
# stream_lua_nginx_module: "v0.0.11"
# lua_resty_core: "v0.1.24"
ENV VAR_LUA_NGINX_MODULE=master
ENV VAR_STREAM_LUA_NGINX_MODULE=master
ENV VAR_LUA_RESTY_CORE=master



ENV JOBS=3
ENV SH=bash
ENV NGX_BUILD_JOBS=3
ENV BASE_PATH=/runner/work/cache
ENV LUAJIT_PREFIX=/runner/work/cache/luajit21
ENV LUAJIT_LIB=/runner/work/cache/luajit21/lib
ENV LUAJIT_INC=/runner/work/cache/luajit21/include/luajit-2.1
ENV LUA_INCLUDE_DIR=/runner/work/cache/luajit21/include/luajit-2.1
ENV OPENSSL_PREFIX=/runner/work/cache/ssl
ENV OPENSSL_LIB=/runner/work/cache/ssl/lib
ENV OPENSSL_INC=/runner/work/cache/ssl/include
ENV TEST_NGINX_SLEEP=0.005
ENV TEST_NGINX_RANDOMIZE=1
ENV LUACHECK_VER=0.21.1
ENV CC=gcc
ENV NGX_BUILD_CC=gcc
  
ENV NGINX_CC_OPTS=""
ENV LUAJIT_CC_OPTS=""

RUN apt-get update && apt-get install -y git wget build-essential cpanminus axel ca-certificates
RUN apt-get install -y libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev python3-pip libpcre3 libpcre3-dev

RUN mkdir -p /scripts $OPENSSL_PREFIX $LUAJIT_PREFIX

WORKDIR /runner/work/

ADD ./scripts /scripts
RUN chmod +x /scripts/0-run.sh
RUN find /scripts/setup/*.sh | xargs chmod +x
RUN /scripts/setup/1-setup-tools.sh ; /scripts/setup/2-build-openssl.sh; /scripts/setup/3-build-luajit.sh; /scripts/setup/4-build-lua-cjson.sh; /scripts/setup/5-build-nginx.sh; /scripts/setup/6-build-mockeagain.sh

VOLUME /runner/work/code
VOLUME /runner/work/t
ENTRYPOINT [ "/scripts/0-run.sh" ]
