#!/bin/bash

PRODUCT=$1
if [[ -z "$PRODUCT" ]]; then
    PRODUCT=kuma
fi
VERSION=$2
if [[ -z "$VERSION" ]]; then
    VERSION=2.8.2
fi

RUN_ID=$(shuf -i 100-1000 -n 1)
WORK_DIR=universal-$RUN_ID
mkdir -p $WORK_DIR
echo "Working directory: $WORK_DIR"

if [[ ! -d "./${PRODUCT}-${VERSION}" ]]; then
    BASE_URL=https://docs.konghq.com/mesh
    if [[ "${PRODUCT}" == "kuma" ]]; then
        BASE_URL=https://kuma.io
    fi
    echo "PREPARE: downloading ${PRODUCT} versions ${VERSION}"
    curl -L $BASE_URL/installer.sh | VERSION=${VERSION} sh -
fi

KUMA_CP_TOKEN=$(curl -s http://localhost:5681/global-secrets/admin-user-token | jq -r .data | base64 -d)

# write the kubectl config
./${PRODUCT}-${VERSION}/bin/kumactl config control-planes add --overwrite \
 --name cp-local --address http://localhost:5681 \
 --auth-type tokens --auth-conf token=$KUMA_CP_TOKEN \
 --config-file ./$WORK_DIR/kumactl.config

# generate the dp token using the config
./${PRODUCT}-${VERSION}/bin/kumactl generate dataplane-token \
  --tag kuma.io/service=demo-app-$RUN_ID --valid-for=720h \
  --config-file ./$WORK_DIR/kumactl.config > ./$WORK_DIR/dataplane-token

PORT_INBOUND=$(( 3000 + RUN_ID ))
PORT_SERVICE=$(( 6000 + RUN_ID ))
PORT_ADMIN=$(( 9901 + RUN_ID ))
# generate the dp file
echo ""
cat << EOF > ./$WORK_DIR/dataplane.yaml
type: Dataplane
mesh: default
name: demo-app-$RUN_ID
networking: 
  address: 127.0.0.1
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
./${PRODUCT}-${VERSION}/bin/kuma-dp run \
  --cp-address=https://127.0.0.1:5678 \
  --dns-enabled=false \
  --dataplane-token-file=./$WORK_DIR/dataplane-token \
  --dataplane-file=./$WORK_DIR/dataplane.yaml


