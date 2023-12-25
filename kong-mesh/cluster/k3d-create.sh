#!/bin/bash

set -e

CLUSTER_NAME=startup-task
NUM_NODES=1
K3S_VERSION=v1.23.17-k3s1

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      CLUSTER_NAME="$2"
      shift
      shift
      ;;
    --nodes)
      NUM_NODES="$2"
      shift 
      shift
      ;;
    # -*|--*)
    #   echo "Unknown option $1"
    #   exit 1
    #   ;;
    *)
    #  POSITIONAL_ARGS+=("$1") 
      shift
      ;;
  esac
done


PORT_PREFIX=100
function k3d_node_opts(){
    for IDX in $(seq 0 $((NUM_NODES-1))); do
        echo -n " --k3s-arg --disable=traefik@server:$IDX \
        --k3s-arg --disable=metrics-server@server:$IDX \
        --k3s-arg --disable=servicelb@server:$IDX \
        --port ${PORT_PREFIX}80-${PORT_PREFIX}99:30080-30099@server:$IDX"
        PORT_PREFIX=$((PORT_PREFIX+100))
        if [[ $PORT_PREFIX -gt 600 ]]; then
            >&2 echo "Maximun allowed numbers of nodes is 5 on k3d clusters"
            exit 1
        fi
    done
}


K3D_CLUSTER_CREATE_OPTS="-i rancher/k3s:$K3S_VERSION \
    $(k3d_node_opts)
	--servers $NUM_NODES --subnet 172.28.0.0/16 \
	--timeout 120s"

k3d cluster create "${CLUSTER_NAME}" --servers $NUM_NODES $K3D_CLUSTER_CREATE_OPTS 
sleep 1

k3d kubeconfig merge ${CLUSTER_NAME} --kubeconfig-merge-default
kubectl config set-context k3d-${CLUSTER_NAME}

TIMES_TRIED=0
MAX_ALLOWED_TRIES=30
until kubectl wait -n kube-system --timeout=5s --for condition=Ready --all pods; do
    echo "Waiting for the cluster to come up" && sleep 1
    TIMES_TRIED=$((TIMES_TRIED+1))
    if [[ $$TIMES_TRIED -ge $$MAX_ALLOWED_TRIES ]]; then 
        kubectl get pods -n kube-system -o Name | xargs -I % kubectl -n kube-system describe %
        exit 1
    fi
done


