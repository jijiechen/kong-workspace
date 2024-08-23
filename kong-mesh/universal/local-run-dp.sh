#!/bin/bash

PRODUCT=$1
if [[ -z "$PRODUCT" ]]; then
    PRODUCT=kuma
fi
VERSION=$2
if [[ -z "$VERSION" ]]; then
    VERSION=2.8.2
fi

RUN_ID=${KUMA_DP_RUN_ID}
if [[ "$RUN_ID" == "" ]]; then
  RUN_ID=$(shuf -i 100-1000 -n 1)
fi

WORK_DIR=universal-$RUN_ID
mkdir -p $WORK_DIR
echo "Working directory: $WORK_DIR"

PATH_CP=
PATH_DP=
PATH_CLI=

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
  PATH_DP=$REPO_PATH/build/artifacts-$(go env GOOS)-$(go env GOARCH)/kuma-dp/kuma-dp
  PATH_CLI=$REPO_PATH/build/artifacts-$(go env GOOS)-$(go env GOARCH)/kumactl/kumactl
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
  PATH_DP=./${PRODUCT}-${VERSION}/bin/kuma-dp 
  PATH_CLI=./${PRODUCT}-${VERSION}/bin/kumactl
fi

KUMA_CP_TOKEN=$(curl -s http://localhost:5681/global-secrets/admin-user-token | jq -r .data | base64 -d)

# write the kubectl config
$PATH_CLI config control-planes add --overwrite \
 --name cp-local --address http://localhost:5681 \
 --auth-type tokens --auth-conf token=$KUMA_CP_TOKEN \
 --config-file ./$WORK_DIR/kumactl.config

# generate the dp token using the config
$PATH_CLI generate dataplane-token \
  --tag kuma.io/service=demo-app-$RUN_ID --valid-for=720h \
  --config-file ./$WORK_DIR/kumactl.config > ./$WORK_DIR/dataplane-token

PORT_INBOUND=$(( 3000 + RUN_ID ))
PORT_SERVICE=$(( 6000 + RUN_ID ))
PORT_ADMIN=$(( 9901 + RUN_ID ))
PORT_READINESS=$(( 9902 + RUN_ID ))
PORT_PROBE_PROXY=$(( 9000 + RUN_ID ))

LOCALHOST_EXTERNAL_IP=$(ifconfig en0 | grep 'inet' | grep -v 'prefixlen' | awk '{print $2}')
# generate the dp file
echo ""
cat << EOF > ./$WORK_DIR/dataplane.yaml
type: Dataplane
mesh: default
name: demo-app-$RUN_ID
networking: 
  address: $LOCALHOST_EXTERNAL_IP
  inbound: 
    - port: $PORT_INBOUND
      servicePort: $PORT_SERVICE
      serviceAddress: 127.0.0.1
      tags: 
        kuma.io/service: demo-app-$RUN_ID
        kuma.io/protocol: http
  admin:
    port: $PORT_ADMIN
EOF

echo ""
# finally, run the dp
KUMA_APPLICATION_PROBE_PROXY_PORT=$PORT_PROBE_PROXY KUMA_READINESS_PORT=$PORT_READINESS $PATH_DP run \
  --cp-address=https://127.0.0.1:5678 \
  --dns-enabled=false \
  --dataplane-token-file=./$WORK_DIR/dataplane-token \
  --dataplane-file=./$WORK_DIR/dataplane.yaml


