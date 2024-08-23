#!/bin/bash

PRODUCT=$1
if [[ -z "$PRODUCT" ]]; then
    PRODUCT=kuma
fi
VERSION=$2
if [[ -z "$VERSION" ]]; then
    VERSION=2.8.2
fi


if [[ ! -d "./${PRODUCT}-${VERSION}" ]]; then
    BASE_URL=https://docs.konghq.com/mesh
    if [[ "${PRODUCT}" == "kuma" ]]; then
        BASE_URL=https://kuma.io
    fi
    echo "PREPARE: downloading ${PRODUCT} versions ${VERSION}"
    curl -L $BASE_URL/installer.sh | VERSION=${VERSION} sh -
fi

./${PRODUCT}-${VERSION}/bin/kuma-cp run --log-level info

