#!/bin/bash

set -e

CLUSTER_NAME=startup-task
NUM_NODES=1
# K3S_VERSION=v1.23.17-k3s1
K3S_VERSION=v1.29.1-k3s2

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


NETWORK=kuma-lan
if [[ -z "$(docker network ls --format '{{ .Name }}' | grep $NETWORK)" ]]; then
  docker network create -d=bridge -o com.docker.network.bridge.enable_ip_masquerade=true --ipv6 --subnet "fd00:abcd:1234::0/64" $NETWORK
fi


IFS=. read -ra NETWORK_ADDR_SPACE <<< "$(docker network inspect $NETWORK --format '{{ (index .IPAM.Config 0).Subnet }}')"
IFS=/ read -r _byte prefix <<< "${NETWORK_ADDR_SPACE[3]}"
if [[ "${prefix}" -gt 16 ]]; then
  echo "Unexpected docker network $NETWORK, expecting a prefix of at most 16 bits"
  exit 1
fi

CLS_COUNTER=$(k3d cluster list --no-headers | wc -l)
SUBNET_ID=$((CLS_COUNTER+50))
LB_NET_PREFIX="${NETWORK_ADDR_SPACE[0]}.${NETWORK_ADDR_SPACE[1]}.${SUBNET_ID}.0"
PORT_PREFIX=$((400+10*CLS_COUNTER))
function k3d_node_opts(){
    for IDX in $(seq 0 $((NUM_NODES-1))); do
        echo -n " --k3s-arg --disable=traefik@server:$IDX \
        --k3s-arg --disable=metrics-server@server:$IDX \
        --k3s-arg --disable=servicelb@server:$IDX \
        --k3s-arg --kubelet-arg=eviction-hard=imagefs.available<1%,nodefs.available<1%@server:$IDX \
        --k3s-arg --kubelet-arg=eviction-minimum-reclaim=imagefs.available=1%,nodefs.available=1%@server:$IDX \
        --port ${PORT_PREFIX}80-${PORT_PREFIX}99:30080-30099@server:$IDX"
        PORT_PREFIX=$((PORT_PREFIX+2))
    done
}

K3D_CLUSTER_CREATE_OPTS="-i rancher/k3s:$K3S_VERSION \
    $(k3d_node_opts)
	--servers $NUM_NODES --network $NETWORK \
  --timeout 120s"

K3D_FIX_DNS=1 k3d cluster create "${CLUSTER_NAME}" --servers $NUM_NODES $K3D_CLUSTER_CREATE_OPTS 
sleep 1

k3d kubeconfig merge ${CLUSTER_NAME} --kubeconfig-merge-default
k3d kubeconfig get ${CLUSTER_NAME} > ~/.kube/${CLUSTER_NAME}.config
kubectl config use-context k3d-${CLUSTER_NAME}

TIMES_TRIED=0
MAX_ALLOWED_TRIES=30
until kubectl wait -n kube-system --timeout=5s --for condition=Ready --all pods; do
    echo "Waiting for the cluster to come up" && sleep 1
    TIMES_TRIED=$((TIMES_TRIED+1))
    if [[ $TIMES_TRIED -ge $MAX_ALLOWED_TRIES ]]; then 
        kubectl get pods -n kube-system -o Name | xargs -I % kubectl -n kube-system describe %
        exit 1
    fi
done


SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
kubectl apply -f $SCRIPT_PATH/k3d/metallb/native.yaml

kubectl wait --timeout=90s --for=condition=Ready -n metallb-system --all pods
sed "s/NET_PREFIX/$LB_NET_PREFIX/g" $SCRIPT_PATH/k3d/metallb/net.yaml | kubectl apply -f -
# todo: on macOS, route to docker host: https://blog.kubernauts.io/k3s-with-k3d-and-metallb-on-mac-923a3255c36e  (https://github.com/AlmirKadric-Published/docker-tuntap-osx)