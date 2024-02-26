#!/bin/bash

export GOLANG_VERSION=1.21.4
export PATH=/usr/local/go/bin:$PATH

set -eux
ARCH="$(arch)"
url=
case "$ARCH" in
'amd64')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz"
    ;;
'x86_64')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz"
    ;;
'arm64')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-arm64.tar.gz"
    ;;
'aarch64')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-arm64.tar.gz"
    ;;
'i386')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-386.tar.gz"
    ;;
'mips64el')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-mips64le.tar.gz"
    ;;
'ppc64el')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-ppc64le.tar.gz"
    ;;
'riscv64')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-riscv64.tar.gz"
    ;;
's390x')
    url="https://dl.google.com/go/go${GOLANG_VERSION}.linux-s390x.tar.gz"
    ;;
*)
    echo >&2 "error: unsupported architecture '$ARCH' (likely packaging update needed)"
    exit 1
esac

if [[ ! -z "$url" ]]; then
    wget -O go.tgz "$url" --progress=dot:giga
    sudo tar -C /usr/local -xzf go.tgz
    rm go.tgz
    go version
fi
