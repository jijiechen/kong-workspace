#!/bin/bash

if [ ! -d "./kuma-counter-demo" ]; then
    git clone https://github.com/kumahq/kuma-counter-demo.git
fi

kubectl apply -f ./kuma-counter-demo/demo.yaml --namespace demo-app
kubectl wait --namespace demo-app deployment/demo-app --for=condition=Available --timeout=60s

# kubectl apply -f ./kuma-counter-demo/demo-v2.yaml
# kubectl wait --namespace kuma-demo deployment/demo-app-v2 --for=condition=Available --timeout=60s

# MeshGateway & MeshGatewayRoute should be applied to the global control plane
# kubectl apply -f ./kuma-counter-demo/gateway.yaml
# curl $(kubectl get svc -n kuma-demo demo-app-gateway -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

