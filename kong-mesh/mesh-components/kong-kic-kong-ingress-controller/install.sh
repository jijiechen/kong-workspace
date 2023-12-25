#!/bin/bash


SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

kubectl apply -f $SCRIPT_PATH/kic/standard-install.yaml
kubectl apply -f $SCRIPT_PATH/kic/gateway.yaml


helm repo add kong https://charts.konghq.com
helm repo update
helm install kong kong/ingress -n kong --create-namespace