#!/bin/bash

# todo: 让 control-plane 容器运行 sleep infinity, 去掉 readiness/liveness probe, 
# todo: 把编译好的 kuma-cp 二进制放到当前路径（要适合 kuma-cp 容器运行）

POD=$1
NS=$2

if [[ -z "$NS" ]]; then
    NS="kong-mesh-system"
fi

kubectl -n $NS exec -c control-plane $POD -- mkdir -p /tmp/kuma-cp-debug/dlv
kubectl -n $NS cp -c control-plane ./kuma-cp $POD:/tmp/kuma-cp-debug/
kubectl -n $NS cp -c control-plane ./dlv-arm64 $POD:/tmp/kuma-cp-debug/dlv/dlv
kubectl -n $NS cp -c control-plane ./dlv_config.yaml $POD:/tmp/kuma-cp-debug/dlv/config.yaml

echo "Please execute port-forward in a separated terminal and attach:"
echo "kubectl -n $NS port-forward pods/$POD 2345:2345"
echo ""

kubectl -n $NS exec -it -c control-plane $POD -- sh -c 'cd /tmp/kuma-cp-debug ; XDG_CONFIG_HOME=/tmp/kuma-cp-debug/ /tmp/kuma-cp-debug/dlv/dlv --listen=:2345 --headless=true --api-version=2 --accept-multiclient --log exec /tmp/kuma-cp-debug./kuma-cp -- run --log-level=info --log-output-path= --config-file=/etc/kuma.io/kuma-control-plane/config.yaml'
