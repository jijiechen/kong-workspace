#!/bin/bash

pushd $(pwd)
CLUSTERS=$1
PROJECT_DIR=$2

cd $PROJECT_DIR
HEAD_SHA=$(git rev-parse HEAD)
SHORT_SHA=${HEAD_SHA:0:9}
function restore_state(){
  git reset --hard $HEAD_SHA
  rm -rf ./deployments/charts/kong-mesh/Chart.lock
  rm -rf ./deployments/charts/kuma/Chart.lock
  popd
}

trap restore_state EXIT INT QUIT TERM


CHART_FILE=./deployments/charts/kong-mesh/Chart.yaml
if [[ ! -f "$CHART_FILE" ]]; then
  CHART_FILE=./deployments/charts/kuma/Chart.yaml
fi

DEPS=$(yq '.dependencies | length' $CHART_FILE)
if [[ "$DEPS" != "0" ]]; then
  yq -i '.dependencies = []' $CHART_FILE
  git add -u deployments/charts
  git commit --allow-empty -m "ci(helm): remove kuma-dependencies"
fi

HEAD_SHA_2=$(git rev-parse HEAD)
if [[ "$DEPS" != "0" ]] || [[ -z "$(docker images | grep $SHORT_SHA)" ]]; then
  make build
  make images
  make docker/tag
fi

rm -rf $PROJECT_DIR/.cr-release-packages
make helm/update-version
git add -u deployments/charts
git commit --allow-empty -m "ci(helm): update versions"
make helm/package

git reset --hard $HEAD_SHA_2
IFS=',' read -r -a CLUSTER_ARR <<< "$CLUSTERS"
for CLS in "${CLUSTER_ARR[@]}"; do
  if [[ "${CLS:0:4}" == "k3d-" ]]; then
    CLS=${CLS:4:}
  fi

  KIND_CLUSTER_NAME=$CLS make k3d/load/images
done
