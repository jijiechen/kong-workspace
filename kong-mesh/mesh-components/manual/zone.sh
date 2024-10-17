#!/bin/bash


GLOBAL_CP_ADMIN_BASE_URL=$1
ZONE_NAME=$2


# from the global CP cluster
kubectl -n kong-mesh-system get secret kong-mesh-apiserver-tls -o yaml > apiserver-tls.yaml
kubectl -n kong-mesh-system get secret kong-mesh-tls-cert -o 'jsonpath={.data.ca\.crt}' | base64 --decode > kuma_ca_cert.pem


# to the zone CP cluster
# install the same kong-mesh-apiserver-tls with the global CP
kubectl -n kong-mesh-system create -f apiserver-tls.yaml
kubectl -n kong-mesh-system create secret generic kong-mesh-global-cp-kds-ca --from-file=ca.crt=kuma_ca_cert.pem

# kumactl generate zone-token --zone $ZONE_NAME --scope cp --valid-for 43920h
ADMIN_USER_TOKEN=$(kubectl get secret -n kong-mesh-system  admin-user-token -o 'jsonpath={.data.value}' | base64 --decode)
curl -k -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $ADMIN_USER_TOKEN" \
    --data '{\"zone\": \"$ZONE_NAME\", \"validFor\": \"43920h\", \"scope\": [\"cp\"]}' \
    $GLOBAL_CP_ADMIN_BASE_URL/tokens/zone > ./zone-token-$ZONE_NAME
kubectl create -n kong-mesh-system secret generic kong-mesh-global-cp-token --from-file=token=./zone-token-$ZONE_NAME






# install:
helm install  --namespace kong-mesh-system --create-namespace \
 kong-mesh  kong-mesh/kong-mesh -f ./values.yaml \
 --set 'kuma.controlPlane.mode=zone' \
 --set 'kuma.controlPlane.zone=zone2' \
 --set 'kuma.controlPlane.kdsGlobalAddress=grpcs://172.18.52.0:5685'