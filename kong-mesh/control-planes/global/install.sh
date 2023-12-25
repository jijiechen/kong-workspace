#!/bin/bash

GLOBAL_NS=$1

echo "Installing new global control plane in namespace $GLOBAL_NS..."

HELM_RELEASE_NAME=postgres-kong-cp
BASE64_HOST=$(echo -n "${HELM_RELEASE_NAME}-postgresql.${GLOBAL_NS}.svc" | base64 -w 0 2>/dev/null || echo -n "${HELM_RELEASE_NAME}-postgresql.${GLOBAL_NS}.svc" | base64)

DB_PWD=$(openssl rand -base64 12)
BASE64_PWD=$(echo -n "$DB_PWD" | base64 -w 0 2>/dev/null || echo -n "$DB_PWD" | base64)

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "-> Installing PostgreSQL..."
helm install $HELM_RELEASE_NAME oci://registry-1.docker.io/bitnamicharts/postgresql \
  --namespace $GLOBAL_NS --create-namespace \
  --set "auth.username=kong" --set "auth.password=$DB_PWD" --set "auth.database=kongmesh"
cat $SCRIPT_PATH/secrets.yaml | sed "s;POSTGRES_HOSTNAME;$BASE64_HOST;g" | sed "s;RANDOM_PASSWORD;$BASE64_PWD;g" | kubectl create -n $GLOBAL_NS -f -


sleep 3
echo "-> Installing global Kong Control Plane..."
helm repo add kong-mesh https://kong.github.io/kong-mesh-charts
helm install kong-mesh -f $SCRIPT_PATH/values.yaml --skip-crds --create-namespace --namespace $GLOBAL_NS --version 2.4.3 kong-mesh/kong-mesh

echo "-> Waiting for global control plane to be ready..."
kubectl wait --namespace $GLOBAL_NS deployment/kong-mesh-control-plane --for=condition=Available --timeout=90s
