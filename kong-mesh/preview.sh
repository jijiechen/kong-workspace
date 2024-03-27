#!/bin/bash

# set -x

PROJ_NAME=$1
PACKAGE_ONLY=$2
if [[ "$PROJ_NAME" != "kong-mesh" ]] && [[ "$PROJ_NAME" != "kuma" ]]; then
    echo "Only 'kuma' or 'kong-mesh' supported."
    exit 1
fi

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


REPO_ORG=Kong
if [[ "$PROJ_NAME" == "kuma" ]]; then
    REPO_ORG=${GIT_PERSONAL_ORG}
    if [[ -z "$REPO_ORG" ]]; then
        REPO_ORG=$USER
    fi
fi
REPO_PATH=$HOME/go/src/github.com/$REPO_ORG/$PROJ_NAME
cd $REPO_PATH

if [ ! -z "$(git status --porcelain)" ]; then 
  echo "Working tree is not git-clean at '$REPO_PATH'"
  echo "Please commit or stash them before executing this action"
  exit 1
fi

GIT_SHA=$(git rev-parse HEAD)

make images
make docker/tag

make helm/update-version
yq -i 'del(.dependencies)' $REPO_PATH/deployments/charts/$PROJ_NAME/Chart.yaml

git add -u deployments/charts
git commit --allow-empty -m "ci(helm): update versions"

VERSION=$(yq '.version' deployments/charts/$PROJ_NAME/Chart.yaml)
make helm/package || true
if [[ ! -f ".cr-release-packages/${PROJ_NAME}-${VERSION}.tgz" ]]; then
    echo "Failed to package helm chart"
    exit 1
fi

APPS=(kuma-universal kuma-cni kuma-init kuma-dp kuma-cp kumactl)
declare -a IMAGES
IAMGE_REPO_PREFIX=kong
if [[ "$PROJ_NAME" == "kuma" ]]; then
    IAMGE_REPO_PREFIX=kumahq
fi
for APP in "${APPS[@]}"; do
    IMAGES+=( "${IAMGE_REPO_PREFIX}/${APP}:${VERSION}" )
done

IS_OPENSHIFT=
if [[ ! -z "$(kubectl get crd builds.config.openshift.io --no-headers --request-timeout 3)" ]]; then
    IS_OPENSHIFT=1
fi

if [[ ! -z "${PACKAGE_ONLY}" ]]; then
    echo "Please load images to the cluster and run the command manually:"
    echo "helm install $PROJ_NAME --namespace $PROJ_NAME-system \\"
    echo "    --set \"${SETTINGS_PREFIX}controlPlane.mode=standalone\" \\"
    if [[ ! -z "$IS_OPENSHIFT" ]]; then
        echo "    --set \"global.image.registry=image-registry.openshift-image-registry.svc:5000/$PROJ_NAME-system\" \\"
    fi
    echo "    $REPO_PATH/.cr-release-packages/${PROJ_NAME}-${VERSION}.tgz"
    exit 0
fi

if [[ ! -z "${IS_OPENSHIFT}" ]]; then
    $SCRIPT_PATH/install-prebuilt-images-on-ocp.sh $REPO_PATH/.cr-release-packages/${PROJ_NAME}-${VERSION}.tgz
else
    K3D_CLUSTER_NAME="${USER}-poc-1"
    if [[ ! -z "$(k3d cluster list | grep $K3D_CLUSTER_NAME)" ]]; then
        k3d cluster delete $K3D_CLUSTER_NAME
    fi
    $SCRIPT_PATH/setup.sh --create-cluster

    ALL_IMAGES=$(IFS=' '; echo "${IMAGES[*]}")
    for i in 1 2 3 4 5; do
        if k3d image import --mode=direct --cluster=${K3D_CLUSTER_NAME} $ALL_IMAGES --verbose ; then
            break
        else
            echo "Image import failed. Retrying..."; 
        fi
    done
    $SCRIPT_PATH/setup.sh --control-plane --product $PROJ_NAME --version $REPO_PATH/.cr-release-packages/${PROJ_NAME}-${VERSION}.tgz
fi
