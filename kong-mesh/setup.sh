#!/bin/bash

# set -x
set -e

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
USERNAME=$(whoami)
# create the clusters...
# $SCRIPT_PATH/cluster/gcp-create.sh --name ${USERNAME}-starter-1 --nodes 2 --region europe-west1-c
# $SCRIPT_PATH/cluster/gcp-create.sh --name ${USERNAME}-starter-2 --nodes 2 --region asia-east1-a

# context_name
GLOBAL_CONTEXT='gke_team-mesh_europe-west1-c_${USERNAME}-starter-1'
# zone1=context_name1,zone2=context_name2
ZONE_CONTEXTS='eu=gke_team-mesh_europe-west1-c_${USERNAME}-starter-1,asia=gke_team-mesh_asia-east1-a_${USERNAME}-starter-2'

GLOBAL_NS=kong-mesh-global
ZONE_NS=kong-mesh-system


echo "Switching to global zone: $GLOBAL_CONTEXT"
kubectl config use-context $GLOBAL_CONTEXT
EXISTING_NAME=$(kubectl --namespace $GLOBAL_NS  get service/kong-mesh-global-zone-sync  -o  Name || true)
if [ -z "$EXISTING_NAME" ]; then
    $SCRIPT_PATH/control-planes/global/install.sh "$GLOBAL_NS"
else
  echo "Existing global control plane found in namespace $GLOBAL_NS"
fi

echo
echo "Trying to get sync endpoint from global control plane..."
timeout 90s bash -c "until [ -n \"\$(kubectl --namespace $GLOBAL_NS  get service/kong-mesh-global-zone-sync  -o jsonpath='{.status.loadBalancer.ingress[*].ip}')\" ]; do sleep 2; done"
EXTERNAL_IP=$(kubectl --namespace $GLOBAL_NS  get service/kong-mesh-global-zone-sync  -o jsonpath='{.status.loadBalancer.ingress[*].ip}')
if [ -z "$EXTERNAL_IP" ]; then
  echo "Can not determine a public IP address for the sync endpoint from global control plane."
  exit 1
fi

SYNC_ENDPOINT=${EXTERNAL_IP}:5685
echo "Zone sync endpoint in global Control Plane is:"
echo "$SYNC_ENDPOINT"


echo
IFS=',' read -r -a ZONE_CTXS <<< "$ZONE_CONTEXTS"
for ZONE in "${ZONE_CTXS[@]}"; do
    ZONE_NAME=$(echo -n $ZONE | cut -d '=' -f 1)
    ZONE_CTX=$(echo -n $ZONE | cut -d '=' -f 2)

    echo "Installing zone control plane for $ZONE_NAME..."
    kubectl config use-context $ZONE_CTX

    $SCRIPT_PATH/control-planes/zone/install.sh "$ZONE_NAME" "$ZONE_NS" "$SYNC_ENDPOINT"
done

# To configure kumactl:
# kubectl config use-context $GLOBAL_CONTEXT
# kubectl -n kong-mesh-global port-forward svc/kong-mesh-control-plane 5681:5681 &
# kumactl config control-planes add --name kong-mesh --address http://localhost:5681 --skip-verify
