#!/bin/bash

set -e

POD_LIST=$1
NS=$2

if [ -z "$NS" ]; then
    NS=$(kubectl config view --minify | grep 'namespace:' | awk '{print $2}')
fi

function enable_logging(){
    IFS=',' read -r -a ALL_PODS <<< "$POD_LIST"
    for POD in "${ALL_PODS[@]}"; do
        CONTAINER_NAME=kuma-sidecar
        IS_GATEWAY=$(kubectl -n "$NS" get pods  $POD  -o 'jsonpath={.metadata.annotations}' | grep 'kuma.io/gateway' || true)
        IS_INGRESS=$(kubectl -n "$NS" get pods  $POD  -o 'jsonpath={.metadata.annotations}' | grep 'kuma.io/ingress' || true)
        IS_EGRESS=$(kubectl -n "$NS" get pods  $POD  -o 'jsonpath={.metadata.annotations}' | grep 'kuma.io/egress' || true)
        if [ ! -z "$IS_GATEWAY" ]; then
            CONTAINER_NAME=kuma-gateway
        fi
        if [ ! -z "$IS_INGRESS" ]; then
            CONTAINER_NAME=ingress
        fi
        if [ ! -z "$IS_EGRESS" ]; then
            CONTAINER_NAME=egress
        fi

        echo "Streaming $POD..."
        kubectl -n "$NS" exec "$POD" -c $CONTAINER_NAME -- sh -c "wget -O /dev/null --post-data ''  http://localhost:9901/logging?level=debug >/dev/null 2>&1" 
        kubectl -n "$NS" exec "$POD" -c $CONTAINER_NAME -- sh -c "wget -O /dev/stdout http://localhost:9901/config_dump?include_eds 2>/dev/null" > ./${POD}-config.json
        kubectl -n "$NS" logs "$POD" -c $CONTAINER_NAME --tail 1 -f > ./${POD}-envoy.log &
    done
}

function disable_logging(){
    IFS=',' read -r -a ALL_PODS <<< "$POD_LIST"
    for POD in "${ALL_PODS[@]}"; do
        CONTAINER_NAME=kuma-sidecar
        IS_GATEWAY=$(kubectl -n "$NS" get pods  $POD  -o 'jsonpath={.metadata.annotations}' | grep 'kuma.io/gateway' || true)
        IS_INGRESS=$(kubectl -n "$NS" get pods  $POD  -o 'jsonpath={.metadata.annotations}' | grep 'kuma.io/ingress' || true)
        IS_EGRESS=$(kubectl -n "$NS" get pods  $POD  -o 'jsonpath={.metadata.annotations}' | grep 'kuma.io/egress' || true)
        if [ ! -z "$IS_GATEWAY" ]; then
            CONTAINER_NAME=kuma-gateway
        fi
        if [ ! -z "$IS_INGRESS" ]; then
            CONTAINER_NAME=ingress
        fi
        if [ ! -z "$IS_EGRESS" ]; then
            CONTAINER_NAME=egress
        fi
        kubectl -n "$NS" exec "$POD" -c $CONTAINER_NAME -- sh -c "wget -O /dev/null --post-data ''  http://localhost:9901/logging?level=info  >/dev/null 2>&1"
    done

    kill -15 $(jobs -p) > /dev/null 2>&1 || true
}



enable_logging


trap disable_logging EXIT INT QUIT TERM

echo ""
echo "Press Ctrl+C to exit..."
read -r -d '' _ </dev/tty

