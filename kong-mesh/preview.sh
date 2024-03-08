#!/bin/bash

# set -x

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
pushd $(pwd)
GIT_SHA=
function restore_state(){
  if [[ ! -z "$GIT_SHA" ]]; then
    git reset --hard $GIT_SHA
  fi
  popd
}
trap restore_state EXIT INT QUIT TERM

PROJ_NAME=$1
if [[ "$PROJ_NAME" != "kong-mesh" ]] && [[ "$PROJ_NAME" != "kuma" ]]; then
    echo "Only 'kuma' or 'kong-mesh' supported."
    exit 1
fi

REPO_ORG=Kong
if [[ "$PROJ_NAME" == "kuma" ]]; then
    REPO_ORG=${GIT_PERSONAL_ORG}
    if [[ -z "$REPO_ORG" ]]; then
        REPO_ORG=$USER
    fi
fi
REPO_PATH=$HOME/go/src/github.com/$REPO_ORG/$PROJ_NAME
cd $REPO_PATH
GIT_SHA=$(git rev-parse HEAD)

make images
make docker/tag

make helm/update-version
yq -i 'del(.dependencies)' $REPO_PATH/deployments/charts/kong-mesh/Chart.yaml

git add -u deployments/charts
git commit --allow-empty -m "ci(helm): update versions"

VERSION=$(yq '.version' deployments/charts/kong-mesh/Chart.yaml)
make helm/package || true
if [[ ! -f ".cr-release-packages/${PROJ_NAME}-${VERSION}.tgz" ]]; then
    echo "Failed to package helm chart"
    exit 1
fi

$SCRIPT_PATH/setup.sh --create-cluster

APPS=(kuma-universal kuma-cni kuma-init kuma-dp kuma-cp kumactl)
declare -a IMAGES
IAMGE_REPO_PREFIX=kong
if [[ "$PROJ_NAME" == "kuma" ]]; then
    IAMGE_REPO_PREFIX=kumahq
fi
for APP in "${APPS[@]}"; do
    IMAGES+=( "${IAMGE_REPO_PREFIX}/${APP}:${VERSION}" )
done

ALL_IMAGES=$(IFS=' '; echo "${IMAGES[*]}")
K3D_CLUSTER_NAME="${USER}-poc-1"
for i in 1 2 3 4 5; do
    if k3d image import --mode=direct --cluster=${K3D_CLUSTER_NAME} $ALL_IMAGES --verbose ; then
        break
    else
        echo "Image import failed. Retrying..."; 
    fi
done

$SCRIPT_PATH/setup.sh --control-plane --product $PROJ_NAME --version $(pwd)/.cr-release-packages/${PROJ_NAME}-${VERSION}.tgz

