#!/bin/bash

BRANCH=$1
if [[ "$BRANCH" == "" ]]; then
    BRANCH=master
fi

export PATH=/usr/local/go/bin:$PATH

mkdir -p /root/go/src/github.com/kumahq/kuma
cd /root/go/src/github.com/kumahq/kuma
git clone git@github.com:kumahq/kuma.git .

mkdir -p /root/go/src/github.com/Kong/kong-mesh
cd /root/go/src/github.com/Kong/
ln -s /root/go/src/github.com/kumahq/kuma kuma

cd kong-mesh
git clone git@github.com:Kong/kong-mesh.git .


git checkout --track origin/$BRANCH
make dev/tools
make build