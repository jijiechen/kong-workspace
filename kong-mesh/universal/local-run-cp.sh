#!/bin/bash

PRODUCT=$1
if [[ -z "$PRODUCT" ]]; then
    PRODUCT=kuma
fi
VERSION=$2
if [[ -z "$VERSION" ]]; then
    VERSION=2.8.2
fi

PATH_CP=

if [[ "$VERSION" == "preview" ]]; then
  REPO_ORG=Kong
  if [[ "$PRODUCT" == "kuma" ]]; then
      REPO_ORG=${GIT_PERSONAL_ORG}
      if [[ -z "$REPO_ORG" ]]; then
          REPO_ORG=$USER
      fi
  fi
  REPO_PATH=$HOME/go/src/github.com/$REPO_ORG/$PRODUCT
  PATH_CP=$REPO_PATH/build/artifacts-$(go env GOOS)-$(go env GOARCH)/kuma-cp/kuma-cp
else
  if [[ ! -d "./${PRODUCT}-${VERSION}" ]]; then
      BASE_URL=https://docs.konghq.com/mesh
      if [[ "${PRODUCT}" == "kuma" ]]; then
          BASE_URL=https://kuma.io
      fi
      echo "PREPARE: downloading ${PRODUCT} versions ${VERSION}"
      curl -L $BASE_URL/installer.sh | VERSION=${VERSION} sh -
  fi
  PATH_CP=./${PRODUCT}-${VERSION}/bin/kuma-cp
fi

$PATH_CP run --log-level info

