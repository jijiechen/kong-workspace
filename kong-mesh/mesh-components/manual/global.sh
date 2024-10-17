#!/bin/bash

# same steps for standalone zones
MODE=$1
if [[ "$MODE" == "" ]]; then
    MODE=global
fi

../../script-snippets/gen-cert.sh kong-mesh-api-server.local
kubectl create  -n kong-mesh-system secret tls  \
    kong-mesh-apiserver-tls --key=./tls.key --cert=./tls.crt
kubectl create  -n kong-mesh-system secret generic \
   kong-mesh-license --from-file license.json=$KMESH_LICENSE

helm install  --namespace kong-mesh-system --create-namespace kong-mesh  \
  kong-mesh/kong-mesh -f ./values.yaml --set "kuma.controlPlane.mode=$MODE"
