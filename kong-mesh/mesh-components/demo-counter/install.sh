#!/bin/bash

ZONE=$1

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if [ ! -d "$SCRIPT_PATH/kuma-counter-demo" ]; then
    git clone https://github.com/kumahq/kuma-counter-demo.git
else
    (cd $SCRIPT_PATH/kuma-counter-demo ; git pull)
fi

if [[ ! -z "$ZONE" ]]; then
    sed "s/\"local\"/\"$ZONE\"/g" $SCRIPT_PATH/kuma-counter-demo/demo.yaml | kubectl apply -f -
else
    kubectl apply -f $SCRIPT_PATH/kuma-counter-demo/demo.yaml
fi

kubectl wait --namespace kuma-demo deployment/demo-app --for=condition=Available --timeout=60s

# kubectl apply -f ./kuma-counter-demo/demo-v2.yaml
# kubectl wait --namespace kuma-demo deployment/demo-app-v2 --for=condition=Available --timeout=60s

# MeshGateway & MeshGatewayRoute should be applied to the global control plane
# kubectl apply -f ./kuma-counter-demo/gateway.yaml
# curl $(kubectl get svc -n kuma-demo demo-app-gateway -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

