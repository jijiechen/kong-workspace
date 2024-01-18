#!/bin/bash


PRODUCT_NAME=$1
PRODUCT_VERSION=$2
ZONE_NAME=$3
ZONE_NS=$4
SYNC_ENDPOINT=$5

SETTING_PREFIX='kuma.'
if [[ "$PRODUCT_NAME" == "kuma" ]]; then
SETTING_PREFIX=
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
fi

helm repo add $HELM_REPO_NAME "$HELM_REPO_URL"

if [[ "$SYNC_ENDPOINT" == "" ]]; then
  helm install ${PRODUCT_NAME}  --create-namespace --namespace $ZONE_NS \
    --set "${SETTING_PREFIX}controlPlane.mode=standalone" \
    --version $PRODUCT_VERSION $HELM_REPO_NAME/$HELM_CHART
else
  helm install ${PRODUCT_NAME} --create-namespace --namespace $ZONE_NS \
    --set "${SETTING_PREFIX}controlPlane.mode=zone" \
    --set "${SETTING_PREFIX}controlPlane.zone=$ZONE_NAME" \
    --set "${SETTING_PREFIX}ingress.enabled=true" \
    --set "${SETTING_PREFIX}controlPlane.kdsGlobalAddress=grpcs://$SYNC_ENDPOINT" \
    --set "${SETTING_PREFIX}controlPlane.tls.kdsZoneClient.skipVerify=true" \
    --version $PRODUCT_VERSION $HELM_REPO_NAME/$HELM_CHART
fi

kubectl wait deployment/${PRODUCT_NAME}-control-plane --namespace $ZONE_NS --for=condition=Available --timeout=60s
