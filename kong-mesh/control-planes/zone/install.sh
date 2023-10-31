#!/bin/bash


ZONE_NAME=$1
ZONE_NS=$2
SYNC_ENDPOINT=$3


helm install --create-namespace --namespace $ZONE_NS \
  --set "kuma.controlPlane.mode=zone" \
  --set "kuma.controlPlane.zone=$ZONE_NAME" \
  --set "kuma.ingress.enabled=true" \
  --set "kuma.controlPlane.kdsGlobalAddress=grpcs://$SYNC_ENDPOINT" \
  --set "kuma.controlPlane.tls.kdsZoneClient.skipVerify=true" \
  kong-mesh kong-mesh/kong-mesh

kubectl wait deployment/kong-mesh-control-plane --namespace $ZONE_NS --for=condition=Available --timeout=60s
