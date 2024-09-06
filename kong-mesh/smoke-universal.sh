#!/bin/bash

set -e
# set -x

PRODUCT=$1
if [[ -z "$PRODUCT" ]]; then
    PRODUCT=kuma
fi
VERSION=$2
if [[ -z "$VERSION" ]]; then
    echo "Please specify a version to check"
    exit 1
fi

CP_IMAGE=kumahq/kuma-cp:$VERSION
DP_IMAGE=kumahq/kuma-dp:$VERSION
CLI_IMAGE=kumahq/kumactl:$VERSION

if [[ "$PRODUCT" == "kong-mesh" ]]; then
    CP_IMAGE=kong/kuma-cp:$VERSION
    DP_IMAGE=kong/kuma-dp:$VERSION
    CLI_IMAGE=kong/kumactl:$VERSION
fi

NETWORK_NAME=kuma-lan
if [[ -z "$(docker network ls --format '{{ .Name }}' | grep $NETWORK_NAME)" ]]; then
  docker network create -d=bridge -o com.docker.network.bridge.enable_ip_masquerade=true --ipv6 --subnet "fd00:abcd:1234::0/64" $NETWORK_NAME
fi


CONTAINER_NAME_CP=kuma-cp-universal-$VERSION
CONTAINER_NAME_DP=kuma-dp-universal-$VERSION
CONTAINER_NAME_CLI=kumactl-$VERSION
WORK_DIR=smoke-universal-$VERSION-$RANDOM
mkdir -p $WORK_DIR
echo "Working directory: $WORK_DIR"

function cleanup(){
    docker rm -f $CONTAINER_NAME_CP || true
    docker rm -f $CONTAINER_NAME_DP || true
}
trap cleanup EXIT INT QUIT TERM

echo ""
echo "STEP 1: Starting the kuma-cp..."
docker run -d --name $CONTAINER_NAME_CP --network $NETWORK_NAME $CP_IMAGE run --log-level info
sleep 5
CP_TOKEN=$(bash -c "docker exec -it $CONTAINER_NAME_CP wget -q -O - http://localhost:5681/global-secrets/admin-user-token" | jq -r .data | base64 -d)
CP_IP_ADDR=$(docker inspect $CONTAINER_NAME_CP | jq -r ".[0].NetworkSettings.Networks[\"$NETWORK_NAME\"].IPAddress")

echo ""
echo "STEP 2: Generating dataplane tokens..."
docker run --rm --name $CONTAINER_NAME_CLI --network $NETWORK_NAME -v $(pwd):/host $CLI_IMAGE config control-planes add --name cp --address http://$CP_IP_ADDR:5681 --auth-type tokens --auth-conf token=$CP_TOKEN --config-file /host/$WORK_DIR/kumactl.config

docker run --rm --name $CONTAINER_NAME_CLI --network $NETWORK_NAME -v $(pwd):/host $CLI_IMAGE generate dataplane-token --tag kuma.io/service=demo-app --valid-for=720h --config-file /host/$WORK_DIR/kumactl.config > ./$WORK_DIR/dataplane-token

echo ""
echo "STEP 3: Starting a dataplane..."
cat << EOF > ./$WORK_DIR/dataplane.yaml
type: Dataplane
mesh: default
name: demo-app
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
    port: 9901
EOF
docker run -d --name $CONTAINER_NAME_DP --network $NETWORK_NAME -v $(pwd):/host $DP_IMAGE run \
  --cp-address=https://$CP_IP_ADDR:5678 \
  --dns-enabled=false \
  --dataplane-token-file=/host/$WORK_DIR/dataplane-token \
  --dataplane-file=/host/$WORK_DIR/dataplane.yaml

sleep 5

echo ""
echo "STEP 4: Creating some policies..."
cat << EOF > ./$WORK_DIR/policy-mtls.yaml
type: Mesh
name: default
mtls:
  enabledBackend: ca-1
  backends:
  - name: ca-1
    type: builtin
EOF
cat << EOF > ./$WORK_DIR/policy-mtp.yaml
type: MeshTrafficPermission
name: allow-all
mesh: default
spec:
  targetRef:
    kind: Mesh
  from:
  - targetRef:
      kind: Mesh
    default:
      action: Allow
EOF

sleep 1
docker run --rm --name $CONTAINER_NAME_CLI --network $NETWORK_NAME -v $(pwd):/host $CLI_IMAGE --config-file /host/$WORK_DIR/kumactl.config apply -f /host/$WORK_DIR/policy-mtls.yaml
docker run --rm --name $CONTAINER_NAME_CLI --network $NETWORK_NAME -v $(pwd):/host $CLI_IMAGE --config-file /host/$WORK_DIR/kumactl.config apply -f /host/$WORK_DIR/policy-mtp.yaml
sleep 5

echo ""
echo "STEP 5: Finishing..."
CP_RUNNING=$(docker ps | grep $CONTAINER_NAME_CP || true)
DP_RUNNING=$(docker ps | grep $CONTAINER_NAME_DP || true)

echo ""
echo "======== KUMA CONTROL PLANE LOGS =========="
docker logs --tail 100 $CONTAINER_NAME_CP

echo ""
echo ""
echo "======== KUMA DATAPLANE LOGS =========="
docker logs --tail 100 $CONTAINER_NAME_DP

FAIL=
if [[ -z "$CP_RUNNING" ]]; then
    FAIL=1
    echo ""
    echo ""
    echo "kuma-cp container exited unexpectedly!"
fi
if [[ -z "$DP_RUNNING" ]]; then
    FAIL=1
    echo ""
    echo ""
    echo "kuma-dp dontainer exited unexpectedly!"
fi

if [[ -z "$FAIL" ]]; then
    echo ""
    echo ""
    echo "SUCCESS!"
fi

