#!/bin/bash

set -e

# export KUMA_CP_CONTAINER_NAME=$(run-cp.sh | grep 'Container:' | awk '{print $1}')
PRODUCT=$1
if [[ -z "$PRODUCT" ]]; then
    PRODUCT=kuma
fi

VERSION=$2
if [[ -z "$VERSION" ]]; then
VERSION=2.8.2
fi

if [[ "$KUMA_CP_CONTAINER_NAME" == "" ]]; then
  KUMA_CP_CONTAINER_NAME=$(docker ps | grep  "kuma-cp-universal-$VERSION" | awk '{print $1}' | head -n 1)
  if [[ "$KUMA_CP_CONTAINER_NAME" == "" ]]; then
    SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
    echo "Starting kuma-cp $VERSION..."
    KUMA_CP_CONTAINER_NAME=$($SCRIPT_PATH/run-cp.sh | grep 'Container:' | awk '{print $2}')
    sleep 5
  fi
fi
echo "CP Container: $KUMA_CP_CONTAINER_NAME"


KUMA_CP_IP_ADDR=
KUMA_CP_TOKEN=
KUMA_CP_TOKEN=$(bash -c "docker exec -it $KUMA_CP_CONTAINER_NAME wget -q -O - http://localhost:5681/global-secrets/admin-user-token" | jq -r .data | base64 -d)
KUMA_CP_IP_ADDR=$(docker inspect $KUMA_CP_CONTAINER_NAME | jq -r '.[0].NetworkSettings.IPAddress')
if [[ "$KUMA_CP_IP_ADDR" == "" ]]; then
KUMA_CP_IP_ADDR=$(docker inspect $KUMA_CP_CONTAINER_NAME | jq -r '.[0].NetworkSettings.Networks.[].IPAddress')
fi


DP_IMAGE=kumahq/kuma-dp:$VERSION
CLI_IMAGE=kumahq/kumactl:$VERSION

if [[ "$PRODUCT" == "kong-mesh" ]]; then
    DP_IMAGE=kong/kuma-dp:$VERSION
    CLI_IMAGE=kong/kumactl:$VERSION
fi

RUN_ID=$RANDOM

CONTAINER_NAME_DP=kuma-dp-$RUN_ID
CONTAINER_NAME_CLI=kumactl-$RUN_ID
WORK_DIR=universal-$RUN_ID
mkdir -p $WORK_DIR
echo "Working directory: $WORK_DIR"

CP_NETWORK=$(docker inspect $KUMA_CP_CONTAINER_NAME | jq -r '.[0].NetworkSettings.Networks | keys | .[]' | head -n 1)

# write the kumactl.config
docker run --rm --name $CONTAINER_NAME_CLI --network $CP_NETWORK -v $(pwd):/host $CLI_IMAGE config control-planes add --name cp --address http://$KUMA_CP_IP_ADDR:5681 --auth-type tokens --auth-conf token=$KUMA_CP_TOKEN --config-file /host/$WORK_DIR/kumactl.config

# generate the token
docker run --rm --name $CONTAINER_NAME_CLI --network $CP_NETWORK -v $(pwd):/host $CLI_IMAGE generate dataplane-token --tag kuma.io/service=demo-app-$RUN_ID --valid-for=720h --config-file /host/$WORK_DIR/kumactl.config > ./$WORK_DIR/dataplane-token

echo ""
cat << EOF > ./$WORK_DIR/dataplane.yaml
type: Dataplane
mesh: default
name: demo-app-$RUN_ID
networking: 
  address: 127.0.0.1
  inbound: 
    - port: 15000
      servicePort: 5000
      serviceAddress: 127.0.0.1
      tags: 
        kuma.io/service: demo-app
        kuma.io/protocol: http
  admin:
    port: 9902
EOF

echo ""

docker run -d --rm --name $CONTAINER_NAME_DP --network $CP_NETWORK -v $(pwd):/host \
  $DP_IMAGE run \
  --cp-address=https://$KUMA_CP_IP_ADDR:5678 \
  --dns-enabled=false \
  --dataplane-token-file=/host/$WORK_DIR/dataplane-token \
  --dataplane-file=/host/$WORK_DIR/dataplane.yaml

docker logs -f $CONTAINER_NAME_DP