#!/bin/bash

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

PRODUCT_NAME=$1
PRODUCT_VERSION=$2
ZONE_NAME=$3
ZONE_NS=$4
SYNC_ENDPOINT=$5

SETTING_PREFIX='kuma.'
if [[ "$PRODUCT_NAME" == "kuma" ]]; then
SETTING_PREFIX=
fi

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

helm repo add $HELM_REPO_NAME "$HELM_REPO_URL"
helm repo update

if [[ "$CHART_FILE" == "" ]]; then
  CHART_FILE=$HELM_REPO_NAME/$HELM_CHART
fi

HELM_COMMAND=(helm install ${PRODUCT_NAME}  --create-namespace --namespace $ZONE_NS -f "$VALUES_FILE")
if [[ "$SYNC_ENDPOINT" == "" ]]; then
  HELM_COMMAND+=(--set "${SETTING_PREFIX}controlPlane.mode=standalone")
else
  HELM_COMMAND+=(--set "${SETTING_PREFIX}controlPlane.mode=zone" \
    --set "${SETTING_PREFIX}controlPlane.zone=$ZONE_NAME" \
    --set "${SETTING_PREFIX}ingress.enabled=true" \
    --set "${SETTING_PREFIX}controlPlane.kdsGlobalAddress=grpcs://$SYNC_ENDPOINT" \
    --set "${SETTING_PREFIX}controlPlane.tls.kdsZoneClient.skipVerify=true")
fi
if [[ ! -z "$PRODUCT_VERSION" ]]; then
  HELM_COMMAND+=(--version $PRODUCT_VERSION)
fi
HELM_COMMAND+=($CHART_FILE)
"${HELM_COMMAND[@]}"

kubectl wait deployment/${PRODUCT_NAME}-control-plane --namespace $ZONE_NS --for=condition=Available --timeout=60s
