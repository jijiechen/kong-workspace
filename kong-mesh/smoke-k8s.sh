#!/bin/bash

set -e

PRODUCT=$1
THIS_VER=$2
PREV_VER=$3

MODE=zone
# for versions < 2.6:
# MODE=standalone

WORK_DIR=smoke-k8s-$THIS_VER-$RANDOM
mkdir -p $WORK_DIR
echo "Working directory: $WORK_DIR"
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

BASE_URL=https://docs.konghq.com/mesh
if [[ "${PRODUCT}" == "kuma" ]]; then
    BASE_URL=https://kuma.io
fi


# 1. download two versions
echo "PREPARE: downloading ${PRODUCT} versions ${PREV_VER} and ${THIS_VER}..."
curl -L $BASE_URL/installer.sh | VERSION=${THIS_VER} sh -
curl -L $BASE_URL/installer.sh | VERSION=${PREV_VER} sh -

# 2. create two clusters
echo "PREPARE: deleting existing clusters..."
if [[ $(k3d cluster list | grep -v NAME | grep $USER-poc-1) ]]; then
    k3d cluster delete $USER-poc-1
fi
if [[ $(k3d cluster list | grep -v NAME | grep $USER-poc-2) ]]; then
    k3d cluster delete $USER-poc-2
fi

echo "PREPARE: creating clusters..."
${SCRIPT_PATH}/setup.sh --create-cluster  --multizone
k3d kubeconfig get $USER-poc-1  > ~/.kube/$USER-poc-1.config
k3d kubeconfig get $USER-poc-2  > ~/.kube/$USER-poc-2.config



function dump_info(){
    FILE_PREFIX=$1
    PRINT_CP_IMAGE=$2

    CP_POD=$(kubectl  -n ${PRODUCT}-system get pods -l  app=${PRODUCT}-control-plane | grep Running | head -n 1 | awk '{print $1}')
    echo "control plane is using image: "
    kubectl -n ${PRODUCT}-system get pods ${CP_POD} -o yaml | grep image

    kubectl -n ${PRODUCT}-system logs ${CP_POD} > $WORK_DIR/${FILE_PREFIX}-cp.log

    DP_POD=$(kubectl  -n kuma-demo get pods -l  app=demo-app | grep Running | head -n 1 | awk '{print $1}')
    kubectl -n kuma-demo logs ${DP_POD} -c kuma-sidecar > $WORK_DIR/${FILE_PREFIX}-dp.log
    DP_WORK_DIR=$(kubectl -n kuma-demo exec ${DP_POD}  -c kuma-sidecar -- ls -1 /tmp/ | grep kuma-dp-)
    kubectl -n kuma-demo exec ${DP_POD} -c kuma-sidecar -- cat /tmp/$DP_WORK_DIR/bootstrap.yaml > $WORK_DIR/${FILE_PREFIX}-dp-bootstrap.yaml
}

# 3. cluster 1
kuse $USER-poc-1
echo "INSTALL: install control plane version ${PREV_VER}..."
./${PRODUCT}-${THIS_VER}/bin/kumactl install control-plane --mode $MODE \
       --namespace ${PRODUCT}-system  | kubectl apply -f -
kubectl wait --timeout=90s --for=condition=Ready -n ${PRODUCT}-system --all pods
${SCRIPT_PATH}/mesh-components/demo-counter/install.sh
# todo: request the demo app!
sleep 5
kubectl -n kuma-demo rollout restart deploy/demo-app
kubectl -n kuma-demo rollout status deploy/demo-app
dump_info '1-install'


# 4. cluster 2
kuse $USER-poc-2
echo "UPGRADE: Install control plane version ${PREV_VER}..."
./${PRODUCT}-${PREV_VER}/bin/kumactl install control-plane --mode $MODE \
       --namespace ${PRODUCT}-system  | kubectl apply -f -
kubectl wait --timeout=90s --for=condition=Ready -n ${PRODUCT}-system --all pods
${SCRIPT_PATH}/mesh-components/demo-counter/install.sh
# todo: request the demo app!
sleep 5
dump_info '2-upgrade.1'


echo "UPGRADE: Upgrading control plane to version ${THIS_VER}..."
./${PRODUCT}-${THIS_VER}/bin/kumactl install control-plane --mode $MODE \
       --namespace ${PRODUCT}-system  | kubectl apply -f -
kubectl -n ${PRODUCT}-system rollout status deploy/${PRODUCT}-control-plane
sleep 10
kubectl -n kuma-demo rollout restart deploy/demo-app
kubectl -n kuma-demo rollout status deploy/demo-app
dump_info '2-upgrade.2'

echo "Finished."