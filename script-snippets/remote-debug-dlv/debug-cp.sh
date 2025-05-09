#!/bin/bash

set -e
set -x


SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
PRODUCT_NAME=kuma
PRODUCT_VERSION=
PRODUCT_IMAGE_ORG=kumahq
KUMA_DIR=
PROJECT_DIR=
GOLANG_VERSION=
ARCH=

function get_kuma_dir(){
    REPO_ORG=
    REPO_ORG=${GIT_PERSONAL_ORG:-kumahq}
    if [[ -z "$REPO_ORG" ]]; then
        REPO_ORG=$USER
    fi
    REPO_PATH=$HOME/go/src/github.com/$REPO_ORG/kuma
    if [[ -d "$REPO_PATH" ]]; then
        echo $REPO_PATH
    else
        echo $HOME/go/src/github.com/kumahq/kuma
    fi
}


function prepare_global_vars(){
    KUMA_DIR=$(get_kuma_dir)
    PROJECT_DIR=$KUMA_DIR
    KM_NS=$(kubectl get namespaces -o Name | grep "kong-mesh-" || true)
    if [[ ! -z "$KM_NS" ]]; then
        PRODUCT_NAME=kong-mesh
        PROJECT_DIR=$(echo $HOME/go/src/github.com/Kong/kong-mesh)
        PRODUCT_IMAGE_ORG=kong
    fi

    CP_POD=$(kubectl get pods -l "app=${PRODUCT_NAME}-control-plane" -n "${PRODUCT_NAME}-system" --no-headers -o=custom-columns=NAME:.metadata.name | head -n 1)
    if [[ -z "$CP_POD" ]]; then
        echo "No control plane pod found in namespace '${PRODUCT_NAME}-system'"
        exit 1
    fi
    IMAGE=$(kubectl get pods $CP_POD -n "${PRODUCT_NAME}-system" -o 'jsonpath={.spec.containers[0].image}')
    PRODUCT_VERSION=$(echo "$IMAGE" | cut -d ':' -f 2)

    pushd $(pwd)
    cd $PROJECT_DIR
    git fetch --tags
    git checkout tags/$PRODUCT_VERSION
    GOLANG_VERSION=$(go list -f {{.GoVersion}} -m)
    ARCH=$(make build/info | grep 'arch:' | rev | cut -d '=' -f 1 | rev)
    popd
}


function prepare_dlv(){
    if [[ -f "$SCRIPT_PATH/dlv/dlv-${GOLANG_VERSION}-${ARCH}" ]]; then
        echo "dlv for golang ${GOLANG_VERSION} (${ARCH}) already exists, skip downloading..."
        return
    fi

    echo "trying to download dlv using Kuma base image..."
    pushd $(pwd)
    cd $PROJECT_DIR
    git fetch --tags
    git checkout tags/$PRODUCT_VERSION
    docker images | grep kumahq/base-root-debian | awk '{print $3}' | xargs docker rmi
    make image/base-root/${ARCH}
    BASE_IMAGE=$(docker images | grep kumahq/base-root-debian | awk '{print $1}')
    popd

    TMP_FILE=$(mktemp)
    rm -f $TMP_FILE
    GO_DOWNLOAD_URL=$($SCRIPT_PATH/../init-os/go.sh ${GOLANG_VERSION} ${ARCH} "URL_ONLY")
    curl -o $TMP_FILE -L --fail $GO_DOWNLOAD_URL

    docker run --rm --name dlv-builder-${ARCH} --detach --entrypoint sleep ${BASE_IMAGE}:no-push-${ARCH} infinity
    docker cp $TMP_FILE dlv-builder-${ARCH}:/go.tgz
    docker exec dlv-builder-${ARCH} sh -c "tar -C /usr/bin -xzf /go.tgz"
    docker exec dlv-builder-${ARCH} /usr/bin/go/bin/go install github.com/go-delve/delve/cmd/dlv@latest
    docker cp dlv-builder-${ARCH}:/root/go/bin/dlv $SCRIPT_PATH/dlv/dlv-${GOLANG_VERSION}-${ARCH}
    docker stop dlv-builder-${ARCH}
}

function build_project_with_debug_symbols(){
    pushd $(pwd)
    cd $PROJECT_DIR
    git fetch --tags
    git checkout tags/$PRODUCT_VERSION

    awk '
BEGIN { in_ldflags_block=0 }
/^define LD_FLAGS$/ { in_ldflags_block=1; print; next }
/^endef$/ { in_ldflags_block=0; print; next }
{
    if (in_ldflags_block) {
        gsub(/-s -w[[:space:]]*/, " ", $0)
        print
        next
    }
    if ($0 ~ /^LD_FLAGS[[:space:]]*:?=[[:space:]]*-ldflags=/) {
        # If LD_FLAGS := ... inline, modify it too
        gsub(/-s -w[[:space:]]*/, "", $0)
        print
        next
    }
    if ($0 ~ /^GOFLAGS[[:space:]]*:=/) {
        # Replace GOFLAGS definition
        print "GOFLAGS := -gcflags=all=\"-N -l\" -tags=opa_no_oci"
        next
    }
    print
}
' mk/build.mk > mk/build2.mk
    mv mk/build2.mk mk/build.mk
    rm -rf ./build/artifacts-linux-$ARCH
    docker rmi $PRODUCT_IMAGE_ORG/kuma-cp:${PRODUCT_VERSION}
    EXTRA_GOENV='GOEXPERIMENT=boringcrypto' ENABLED_GOOSES=linux ENABLED_GOARCHES=$ARCH make images
    docker tag $PRODUCT_IMAGE_ORG/kuma-cp:${PRODUCT_VERSION} $PRODUCT_IMAGE_ORG/kuma-cp:${PRODUCT_VERSION}-debug
    # todo: load image into the cluster
    git checkout .
    popd
}

function append_file(){
    echo -n "$2" >> $1
}

function prepare_workload(){
    # disable HPA

    # output to a history revision id
    # you may use this command to rollback the workload:
    # kubectl rollback 

    DEPLOYMENT_NAME=$(kubectl get deploy -l app=${PRODUCT_NAME}-control-plane -n ${PRODUCT_NAME}-system --no-headers -o=custom-columns=NAME:.metadata.name || true)
    if [[ -z "$DEPLOYMENT_NAME" ]]; then
        >&2 echo "No ${PRODUCT_NAME}-control-plane deployment found"
        exit 1
    fi

    DEPLOY_JSON_FILE=$(mktemp)
    kubectl scale deploy $DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system --replicas=1
    kubectl get deploy $DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system -o json > $DEPLOY_JSON_FILE
    CONTAINER_JSON=$(jq -rc ".spec.template.spec.containers[0] //empty" $DEPLOY_JSON_FILE)

    EXISTING_COMMAND=$(echo $CONTAINER_JSON | jq -rc '.command //empty')
    EXISTING_ARGS=$(echo $CONTAINER_JSON | jq -rc '.args //empty')
    EXISTING_PROBE_STARTUP=$(echo $CONTAINER_JSON | jq -rc '.startupProbe //empty')
    EXISTING_PROBE_LIVENESS=$(echo $CONTAINER_JSON | jq -rc '.livenessProbe //empty')
    EXISTING_PROBE_READINESS=$(echo $CONTAINER_JSON | jq -rc '.readinessProbe //empty')
    EXISTING_RUNAS_NONROOT=$(cat $DEPLOY_JSON_FILE | jq -rc '.spec.template.spec.securityContext.runAsNonRoot //empty')
    EXISTING_VOLUMES=$(cat $DEPLOY_JSON_FILE | jq -rc '.spec.template.spec.volumes //empty')
    EXISTING_VOLUMEMOUNTS=$(echo $CONTAINER_JSON | jq -rc '.volumeMounts //empty')

    PATCH_TMP_FILE=$(mktemp)
    append_file $PATCH_TMP_FILE '['
    append_file $PATCH_TMP_FILE "{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/image\", \"value\":\"${PRODUCT_IMAGE_ORG}/kuma-cp:${PRODUCT_VERSION}-debug\"}"

    if [[ ! -z "$EXISTING_COMMAND" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/containers/0/command"}'
    fi
    if [[ ! -z "$EXISTING_ARGS" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/containers/0/args"}'
    fi
    if [[ ! -z "$EXISTING_PROBE_STARTUP" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/containers/0/startupProbe"}'
    fi
    if [[ ! -z "$EXISTING_PROBE_LIVENESS" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/containers/0/livenessProbe"}'
    fi
    if [[ ! -z "$EXISTING_PROBE_READINESS" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/containers/0/readinessProbe"}'
    fi
    if [[ ! -z "$EXISTING_RUNAS_NONROOT" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/securityContext/runAsNonRoot"}'
    fi

    append_file $PATCH_TMP_FILE ',{"op": "add", "path": "/spec/template/spec/containers/0/command", "value":["sleep", "infinity"]}'

    append_file $PATCH_TMP_FILE ']'
    kubectl patch deploy $DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system --type json --patch-file "$PATCH_TMP_FILE"
    
    kubectl rollout status deploy/$DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system
    sleep 5
    NEW_CP_POD=$(kubectl get pods -l "app=${PRODUCT_NAME}-control-plane" -n "${PRODUCT_NAME}-system" --no-headers | grep Running | head -n 1 | awk '{print $1}')
    if [[ -z "$NEW_CP_POD" ]]; then
        echo "No control plane pod found in namespace '${PRODUCT_NAME}-system'"
        exit 1
    fi

    kubectl -n "${PRODUCT_NAME}-system" exec -c control-plane $NEW_CP_POD -- mkdir -p /tmp/kuma-cp-debug/dlv
    kubectl -n "${PRODUCT_NAME}-system" cp -c control-plane $SCRIPT_PATH/dlv/dlv-${GOLANG_VERSION}-${ARCH} $NEW_CP_POD:/tmp/kuma-cp-debug/dlv/dlv
    kubectl -n "${PRODUCT_NAME}-system" cp -c control-plane $SCRIPT_PATH/dlv_config.yaml $NEW_CP_POD:/tmp/kuma-cp-debug/dlv/config.yaml
}

function start_processes(){
    CP_POD=$(kubectl get pods -l "app=${PRODUCT_NAME}-control-plane" -n "${PRODUCT_NAME}-system" --no-headers | grep Running | head -n 1 | awk '{print $1}')

    kubectl -n "${PRODUCT_NAME}-system" exec -c control-plane $CP_POD  -- sh -c 'cd /tmp/kuma-cp-debug ; XDG_CONFIG_HOME=/tmp/kuma-cp-debug/ /tmp/kuma-cp-debug/dlv/dlv --listen=:2345 --headless=true --api-version=2 --accept-multiclient --log exec kuma-cp -- run --log-level=info --log-output-path= --config-file=/etc/kuma.io/kuma-control-plane/config.yaml &'
    kubectl -n "${PRODUCT_NAME}-system" port-forward pods/$CP_POD 2345:2345
}

prepare_global_vars
prepare_dlv
build_project_with_debug_symbols
# todo: debug the current source code (without checkout to a tag!)
prepare_workload
start_processes