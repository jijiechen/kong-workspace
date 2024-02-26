#!/bin/bash

# todo: 事先制作 injected deployment
# todo: 让 kuma-sidecar 容器运行 sleep infinity, 去掉 readiness/liveness probe, 
# todo: 把编译好的 kuma-dp 二进制放到当前路径（要适合 kuma-dp 容器运行）
set -x

POD=$1
NS=$2

if [[ -z "$NS" ]]; then
    NS="kuma-demo"
fi

kubectl -n $NS exec -c kuma-sidecar $POD -- mkdir -p /tmp/kuma-dp-debug/dlv
kubectl -n $NS cp -c kuma-sidecar ./kuma-dp $POD:/tmp/kuma-dp-debug/
kubectl -n $NS cp -c kuma-sidecar ./dlv-arm64 $POD:/tmp/kuma-dp-debug/dlv/dlv
kubectl -n $NS cp -c kuma-sidecar ./dlv_config.yaml $POD:/tmp/kuma-dp-debug/dlv/config.yaml

echo "Please execute port-forward in a separated terminal and attach:"
echo "kubectl -n $NS port-forward pods/$POD 2345:2345"
echo ""

kubectl -n $NS exec -it -c kuma-sidecar $POD -- sh -c 'cd /tmp/kuma-dp-debug ; XDG_CONFIG_HOME=/tmp/kuma-dp-debug/ /tmp/kuma-dp-debug/dlv/dlv --listen=:2345 --headless=true --api-version=2 --accept-multiclient --log exec /tmp/kuma-dp-debug/kuma-dp -- run --log-level=info --concurrency=2'
