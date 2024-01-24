#!/bin/bash

PRODUCT_NAME=$1
PRODUCT_VERSION=$2
GLOBAL_NS=$3

echo "Installing new global control plane in namespace $GLOBAL_NS..."

HELM_RELEASE_NAME=postgres-${PRODUCT_NAME}-cp
BASE64_HOST=$(echo -n "${HELM_RELEASE_NAME}-postgresql.${GLOBAL_NS}.svc" | base64 -w 0 2>/dev/null || echo -n "${HELM_RELEASE_NAME}-postgresql.${GLOBAL_NS}.svc" | base64)

DB_PWD=$(openssl rand -base64 12)
BASE64_PWD=$(echo -n "$DB_PWD" | base64 -w 0 2>/dev/null || echo -n "$DB_PWD" | base64)

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "-> Installing PostgreSQL..."
helm install $HELM_RELEASE_NAME oci://registry-1.docker.io/bitnamicharts/postgresql \
  --namespace $GLOBAL_NS --create-namespace \
  --set "auth.username=kuma" --set "auth.password=$DB_PWD" --set "auth.database=kuma"
cat $SCRIPT_PATH/secrets.yaml | sed "s;POSTGRES_HOSTNAME;$BASE64_HOST;g" | sed "s;RANDOM_PASSWORD;$BASE64_PWD;g" | kubectl create -n $GLOBAL_NS -f -


sleep 3
echo "-> Installing global ${PRODUCT_NAME} Control Plane..."

CHART_FILE=
if [[  "$PRODUCT_VERSION" == *".tgz" ]]; then
  CHART_FILE=$PRODUCT_VERSION
  PRODUCT_VERSION=
fi

HELM_REPO_NAME_KUMA=kuma
HELM_REPO_URL_KUMA=https://kumahq.github.io/charts
HELM_CHART_KUMA=kuma

HELM_REPO_NAME_KM=kong-mesh
HELM_REPO_URL_KM=https://kong.github.io/kong-mesh-charts
HELM_CHART_KM=kong-mesh

HELM_REPO_NAME=$HELM_REPO_NAME_KM
HELM_REPO_URL=$HELM_REPO_URL_KM
HELM_CHART=$HELM_CHART_KM
VALUES_FILE=$SCRIPT_PATH/values.yaml
if [[ "$PRODUCT_NAME" == "kuma" ]]; then
  HELM_REPO_NAME=$HELM_REPO_NAME_KUMA
  HELM_REPO_URL=$HELM_REPO_URL_KUMA
  HELM_CHART=$HELM_CHART_KUMA
  TEMP_FILE=$(mktemp)
  yq ea "$VALUES_FILE" -o json  | jq '. += .kuma | del(.kuma) | del(.nameOverride)' | yq e -P > $TEMP_FILE
  VALUES_FILE=$TEMP_FILE
fi

if [[ "$CHART_FILE" == "" ]]; then
  CHART_FILE=$HELM_REPO_NAME/$HELM_CHART
fi
helm repo add $HELM_REPO_NAME "$HELM_REPO_URL"
HELM_COMMAND=(helm install ${PRODUCT_NAME}  -f "$VALUES_FILE" --skip-crds --create-namespace --namespace $GLOBAL_NS)
if [[ ! -z "$PRODUCT_VERSION" ]]; then
  HELM_COMMAND+=(--version $PRODUCT_VERSION)
fi
HELM_COMMAND+=($CHART_FILE)
"${HELM_COMMAND[@]}"


echo "-> Waiting for global control plane to be ready..."
kubectl wait --namespace $GLOBAL_NS deployment/${PRODUCT_NAME}-control-plane --for=condition=Available --timeout=90s
