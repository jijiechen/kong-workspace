#!/bin/bash

PROJ_NAME=$1
VERSION=$2
CLUSTER_NAME=$3

IAMGE_REPO_PREFIX=kong
if [[ "$PROJ_NAME" == "kuma" ]]; then
    IAMGE_REPO_PREFIX=kumahq
fi

APPS=(kuma-universal kuma-cni kuma-init kuma-dp kuma-cp kumactl)
declare -a IMAGES
for APP in "${APPS[@]}"; do
    IMAGES+=( "${IAMGE_REPO_PREFIX}/${APP}:${VERSION}" )
done

K3D_CLUSTER_NAME="${USER}-poc-1"
if [[ "$CLUSTER_NAME" != "" ]]; then
    K3D_CLUSTER_NAME=${CLUSTER_NAME}
fi
ALL_IMAGES=$(IFS=' '; echo "${IMAGES[*]}")
for i in 1 2 3 4 5; do
    if eval "k3d image import --mode=direct --cluster=${K3D_CLUSTER_NAME} ${ALL_IMAGES}" ; then
        break
    else
        echo "Image import failed. Retrying..."; 
    fi
done