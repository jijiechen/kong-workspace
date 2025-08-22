#!/bin/bash

set -e
cd /runner/work/

if [ ! -e lua-cjson ]; then git clone https://github.com/openresty/lua-cjson.git ./lua-cjson; fi
pushd ./lua-cjson && make && PATH=$PATH make install && popd