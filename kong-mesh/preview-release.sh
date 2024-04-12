#!/bin/bash

# preview-release.sh kong-mesh 2.7

PROJECT_NAME=$1
RELEASE=$2
shift
shift


if [[ "$PROJECT_NAME" != "kuma" ]] && [[ "$PROJECT_NAME" != "kong-mesh" ]]; then
    echo "Only 'kong-mesh' and 'kuma' are support for the project name."
    exit 1
fi


REPO=Kong/kong-mesh
if [[ "$PROJECT_NAME" == "kuma" ]]; then
    REPO="kumahq/kuma"
fi

LATEST_BUILD=$(PAGER= gh run list --repo ${REPO} --branch "release-${RELEASE}" --status success --workflow build-test-distribute --limit 1 --json databaseId | jq '.[0].databaseId //empty')
if [[ "${LATEST_BUILD}" == "" ]]; then
    echo "Could not find a successful workflow run for branch 'release-$RELEASE'"
    exit 1
fi

echo "Will use artifact from this run: $LATEST_BUILD"

gh run download ${LATEST_BUILD} --repo ${REPO} --pattern "${PROJECT_NAME}-${RELEASE}.0-preview.*"

CHART=$(ls -1 *.tgz | head -n 1)
if [[ -z "$CHART" ]]; then
    echo "Could not download artifact from build ${LATEST_BUILD}"
    exit 1
fi

TMP_DIR=$(mktemp -d)
tar -C ${TMP_DIR} -xzf $CHART/$CHART
ACTUAL_VERSION=$(yq '.version' ${TMP_DIR}/${PROJECT_NAME}/Chart.yaml)
rm -rf $TMP_DIR
if [[ ! -d "${PROJECT_NAME}-${ACTUAL_VERSION}" ]]; then
    mkdir ${PROJECT_NAME}-${ACTUAL_VERSION}
fi
mv $CHART/$CHART ${PROJECT_NAME}-${ACTUAL_VERSION}/
rm -rf $CHART

ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
OS="${OS:-linux}"

if [[ ! -f "${PROJECT_NAME}-${ACTUAL_VERSION}-${OS}-${ARCH}.tar.gz" ]]; then
    DOWNLOAD_URL=https://download.konghq.com/${PROJECT_NAME}-binaries-preview/${PROJECT_NAME}-${ACTUAL_VERSION}-${OS}-${ARCH}.tar.gz
    if curl --fail --silent --head "$DOWNLOAD_URL" >/dev/null; then
        curl -L -O "$DOWNLOAD_URL"
    else
        if [[ "${PROJECT_NAME}" == "kong-mesh" ]]; then
            curl -L https://docs.konghq.com/mesh/installer.sh | VERSION=${ACTUAL_VERSION} sh -
        else
            curl -L https://kuma.io/installer.sh | VERSION=${ACTUAL_VERSION} sh -
        fi
    fi
fi

BINARY_TAR=$(ls -1 ${PROJECT_NAME}-${ACTUAL_VERSION}-${OS}-${ARCH}.tar.gz | head -n 1)
if [[ -z "$BINARY_TAR" ]]; then
    echo "[WARNING] Unable to download kumactl binaries."
else
    tar -C ./${PROJECT_NAME}-${ACTUAL_VERSION}/ -xzf $BINARY_TAR
    echo "Execute kumactl from ./${PROJECT_NAME}-${ACTUAL_VERSION}/${PROJECT_NAME}/bin/kumactl"
fi

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
$SCRIPT_PATH/setup.sh --product $PROJECT_NAME --version $(pwd)/${PROJECT_NAME}-$ACTUAL_VERSION/$CHART "$@"

