#!/bin/bash


# export KUMACTLBIN=/path/to/preview/kumactl
# set -x

KUMACTL_BIN=${KUMACTLBIN}
if [[ "$KUMACTL_BIN" == "" ]]; then
    KUMACTL_BIN=kumactl
fi

PROJECT_NAME=kuma
KM_NS=$(kubectl get namespaces -o Name | grep "kong-mesh-")
if [[ ! -z "$KM_NS" ]]; then
    PROJECT_NAME=kong-mesh
fi

SYSTEM_NS=$(kubectl get namespace ${PROJECT_NAME}-global -o Name 2>/dev/null || true)
if [[ ! -z "$SYSTEM_NS" ]]; then
    SYSTEM_NS=${PROJECT_NAME}-global
else
    SYSTEM_NS=${PROJECT_NAME}-system
fi

GREEN='\033[1;92m'
YELLOW='\033[0;93m'
NC='\033[0m' # No Color

MULTIZONE_ZONE_NAME=$(kubectl -n ${PROJECT_NAME}-system get deploy  ${PROJECT_NAME}-control-plane -o json | jq -r '.spec.template.spec.containers[0].env[] | select(.name == "KUMA_MULTIZONE_ZONE_NAME") | .value //empty')
if [[ "$MULTIZONE_ZONE_NAME" != "" ]] && [[ "$SYSTEM_NS" == *"-system" ]] ; then
    >&2 printf "${YELLOW}Please switch kubeconfig to global cluster because we are on zone ${MULTIZONE_ZONE_NAME} now\n"
    exit 1
fi

LOCAL_PORT=$(next_available_port 5681)
kubectl port-forward svc/${PROJECT_NAME}-control-plane -n $SYSTEM_NS $LOCAL_PORT:5681 &
echo "Mesh GUI is available at: http://localhost:${LOCAL_PORT}/gui"

if [[ "$MULTIZONE_ZONE_NAME" != "" ]]; then
    export GLOBAL_ADMIN_TOKEN=$(kubectl exec -it -n ${SYSTEM_NS} -c control-plane $(kubectl -n ${SYSTEM_NS} get pods -o Name | grep control-plane | cut -d '/' -f 2) --  wget -q -O - "http://localhost:5681/global-secrets/admin-user-token" | jq -r .data | base64 -d)
    $KUMACTL_BIN config control-planes add --name "${SYSTEM_NS}" --address "http://localhost:${LOCAL_PORT}" \
    --headers "authorization=Bearer $GLOBAL_ADMIN_TOKEN" \
    --overwrite

    printf "${GREEN}Use $KUMACTL_BIN to manage $PROJECT_NAME\n"
else
    printf "${GREEN}Please use kubectl to manage $PROJECT_NAME\n"
fi


