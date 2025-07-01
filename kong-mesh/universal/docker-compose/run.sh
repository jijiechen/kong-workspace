#!/bin/bash

PRODUCT_NAME=$1
PRODUCT_VERSION=$2

# default values
DEFAULT_VERSION=2.11.0
DEFAULT_PRODUCT=kuma
REGISTRY_KUMA=kumahq
REGISTRY_KONG_MESH=kong

if [[ "$PRODUCT_NAME" == "" ]]; then
    PRODUCT_NAME=$DEFAULT_PRODUCT
    PRODUCT_VERSION=$DEFAULT_VERSION
fi
if [[ "$PRODUCT_VERSION" == "" ]]; then
    PRODUCT_VERSION=$DEFAULT_VERSION
fi

REGISTRY=$REGISTRY_KUMA
if [[ "$PRODUCT_NAME" == "kong-mesh" ]]; then
    REGISTRY=$REGISTRY_KONG_MESH
fi

echo "Runing version $PRODUCT_NAME $PRODUCT_VERSION"
PRODUCT_REGISTRY=$REGISTRY PRODUCT_VERSION=$PRODUCT_VERSION docker compose up -d --wait


CP=$(docker compose ps --format "{{.Names}}" | grep kuma-cp)
CP_IP=$(docker inspect --format='{{range.NetworkSettings.Networks}}{{.IPAddress}} {{end}}' $CP | awk '{print $1}')

GW=$(docker compose ps --format "{{.Names}}" | grep gateway)
GW_IP=$(docker inspect --format='{{range.NetworkSettings.Networks}}{{.IPAddress}} {{end}}' $GW | awk '{print $1}')


echo
echo "Endpoints: "
echo "Internal: http://$GW_IP:8080/"
echo "External: http://$GW_IP:8081/"
echo "Mesh GUI: http://$CP_IP:5681/gui"
echo
echo "Commands:"
echo "Watch:   docker compose logs -f"
echo "Stop:    docker compose down"
echo "Cleanup: docker compose rm"

# todo: detect if already running:
# if yes: 
#      detect if running same variables:
#        if yes: show notes
#        if no: restart
# if no: start

# todo: show an overlay view of logs?
# todo: terminate the whole stack when Ctrl+C
# kumactl  config control-planes add --name universal --overwrite --address http://localhost:32874