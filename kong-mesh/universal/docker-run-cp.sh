#!/bin/bash

set -e
# set -x

PRODUCT=$1
if [[ -z "$PRODUCT" ]]; then
    PRODUCT=kuma
fi
VERSION=$2
if [[ -z "$VERSION" ]]; then
    VERSION=2.8.2
fi

CP_IMAGE=kumahq/kuma-cp:$VERSION

if [[ "$PRODUCT" == "kong-mesh" ]]; then
    CP_IMAGE=kong/kuma-cp:$VERSION
fi

NETWORK_NAME=kuma-lan
if [[ -z "$(docker network ls --format '{{ .Name }}' | grep $NETWORK_NAME)" ]]; then
  docker network create -d=bridge -o com.docker.network.bridge.enable_ip_masquerade=true --ipv6 --subnet "fd00:abcd:1234::0/64" $NETWORK_NAME
fi


CONTAINER_NAME_CP=kuma-cp-universal-$VERSION-$RANDOM
echo "Container: $CONTAINER_NAME_CP"
docker run -d --rm --name $CONTAINER_NAME_CP --network $NETWORK_NAME $CP_IMAGE run --log-level info
