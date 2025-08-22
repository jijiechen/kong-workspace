#!/bin/bash

set -e
cd /runner/work/

mkdir -p $OPENSSL_PREFIX/certs/

if [ "X$OPENSSL_HASH" != "X" ]; then wget https://github.com/openssl/openssl/archive/$OPENSSL_HASH.tar.gz -O - | tar zxf ; pushd openssl-$OPENSSL_HASH/; fi
if [ "X$OPENSSL_HASH" = "X" ] ; then wget https://www.openssl.org/source/openssl-${VAR_OPENSSL}.tar.gz -O - | tar zxf -; pushd openssl-${VAR_OPENSSL}/; fi
if [ ! -e $OPENSSL_PREFIX/include ]; then ./config shared -d --prefix=$OPENSSL_PREFIX -DPURIFY > build.log 2>&1 || (cat build.log && exit 1); fi
if [ ! -e $OPENSSL_PREFIX/include ]; then make -j$JOBS > build.log 2>&1 || (cat build.log && exit 1); fi
if [ ! -e $OPENSSL_PREFIX/include ]; then make PATH=$PATH install_sw > build.log 2>&1 || (cat build.log && exit 1); fi
mkdir -p $OPENSSL_PREFIX/certs/ && cp -R "/etc/ssl/certs/"* $OPENSSL_PREFIX/certs/