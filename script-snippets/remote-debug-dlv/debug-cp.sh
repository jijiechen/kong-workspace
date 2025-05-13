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
UPGRADED_RS_REVISION=
DEBUG_IMAGE_TAG=

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
    IMAGE=${IMAGE%-debug*}
    PRODUCT_VERSION=$(echo "$IMAGE" | cut -d ':' -f 2)
}

function build_debug_image(){
    pushd $(pwd)
    cd $PROJECT_DIR

    GET_REF=$(git symbolic-ref --short HEAD 2> /dev/null) || GET_REF=$(git describe --tags --exact-match HEAD 2> /dev/null) || GET_REF=$(git rev-parse --short HEAD 2> /dev/null) || return 0
    GET_REF=${GET_REF//%/%%}
    GIT_STATUS=$(git status --porcelain)
    if [[ "$GET_REF" != "$PRODUCT_VERSION" ]]; then
        if [[ -z "$GIT_STATUS" ]]; then
            git fetch --tags
            git checkout tags/$PRODUCT_VERSION
        else
            echo "Could not checkout to 'tags/$PRODUCT_VERSION', project directory $PROJECT_DIR is not clean."
            exit 1
        fi
    fi

    GOLANG_VERSION=$(go list -f {{.GoVersion}} -m)
    ARCH=$(make build/info | grep 'arch:' | rev | cut -d '=' -f 1 | rev)

    HASH_ELEMENTS=()
    HASH_ELEMENTS+=("${GET_REF}")
    while read DIFF_LINE; do
        if [[ "$DIFF_LINE" == "" ]]; then
            break
        fi

        CHANGE_TYPE=$(echo -n "$DIFF_LINE" | awk '{print $1}')
        CHANGE_FILE=${DIFF_LINE:2}
        if [[ "$CHANGE_TYPE" == "D" ]]; then
            HASH_ELEMENTS+=$($DIFF_LINE)
        elif [[ "$DIFF_LINE" != "mk/build.mk" ]]; then
            FILE_HASH=$(openssl dgst -sha256  $CHANGE_FILE | awk '{print $2}')
            HASH_ELEMENTS+=($FILE_HASH)
        fi
    done < <(echo "$GIT_STATUS")
    DEBUG_HASH=$(echo "${HASH_ELEMENTS[@]}" | openssl dgst -sha256 | awk '{print $2}')
    DEBUG_IMAGE_TAG="${PRODUCT_VERSION}-debug-${DEBUG_HASH:0:12}"

    EXISTING_DEBUG_IMAGE_TAG=$(kubectl get namespace "${PRODUCT_NAME}-system" -o json | jq -r '.metadata.annotations."kuma-cp-debug-image" //empty')
    if [[ ! -z "$EXISTING_DEBUG_IMAGE_TAG" ]] && [[ "$EXISTING_DEBUG_IMAGE_TAG" == "$DEBUG_IMAGE_TAG" ]]; then
        return
    fi

    EXISTING_DEBUG_IMAGE=$(docker images | grep kuma-cp | grep "$DEBUG_IMAGE_TAG" || return 0)
    if [[ ! -z "$EXISTING_DEBUG_IMAGE" ]]; then
        return
    fi

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
    docker rmi --force $PRODUCT_IMAGE_ORG/kuma-cp:${PRODUCT_VERSION}
    EXTRA_GOENV='GOEXPERIMENT=boringcrypto' ENABLED_GOOSES=linux ENABLED_GOARCHES=$ARCH make images
    make docker/tag
    docker tag $PRODUCT_IMAGE_ORG/kuma-cp:${PRODUCT_VERSION} $PRODUCT_IMAGE_ORG/kuma-cp:${DEBUG_IMAGE_TAG}
    git checkout mk/build.mk
    popd
}

function prepare_dlv(){
    if [[ -f "$SCRIPT_PATH/dlv/dlv-${GOLANG_VERSION}-${ARCH}" ]]; then
        echo "dlv for golang ${GOLANG_VERSION} (${ARCH}) already exists, skip downloading..."
        return
    fi

    echo "trying to download dlv using Kuma base image..."
    docker rm -f dlv-builder-${ARCH}
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

function load_image(){
    K3D_CLUSTER_NAME=$1
    IMAGES=$2

    for i in 1 2 3 4 5; do
        if eval "k3d image import --mode=direct --cluster=${K3D_CLUSTER_NAME} ${IMAGES}" ; then
            break
        else
            echo "Image import failed. Retrying..."; 
        fi
    done
}

function load_debug_image_to_k3d(){
    for CLUSTER_NAME in $(k3d cluster list --no-headers -o json | jq -r '.[].name'); do
        load_image ${CLUSTER_NAME} "$PRODUCT_IMAGE_ORG/kuma-cp:${DEBUG_IMAGE_TAG}"
    done
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
    kubectl get deploy $DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system -o json > $DEPLOY_JSON_FILE
    kubectl scale deploy $DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system --replicas=1

    CURRENT_REVISION=$(jq -r '.metadata.annotations["deployment.kubernetes.io/revision"]' $DEPLOY_JSON_FILE)
    CONTAINER_JSON=$(jq -rc ".spec.template.spec.containers[0] //empty" $DEPLOY_JSON_FILE)
    EXISTING_IMAGE=$(echo "$CONTAINER_JSON" | jq -rc '.image //empty')
    EXISTING_COMMAND=$(echo "$CONTAINER_JSON" | jq -rc '.command //empty')
    EXISTING_ARGS=$(echo "$CONTAINER_JSON" | jq -rc '.args //empty')
    EXISTING_PROBE_STARTUP=$(echo "$CONTAINER_JSON" | jq -rc '.startupProbe //empty')
    EXISTING_PROBE_LIVENESS=$(echo "$CONTAINER_JSON" | jq -rc '.livenessProbe //empty')
    EXISTING_PROBE_READINESS=$(echo "$CONTAINER_JSON" | jq -rc '.readinessProbe //empty')
    EXISTING_RESOURCES=$(echo "$CONTAINER_JSON" | jq -rc '.resources //empty')
    EXISTING_RUNAS_NONROOT=$(jq -rc '.spec.template.spec.securityContext.runAsNonRoot //empty' $DEPLOY_JSON_FILE)

    if [[ "$EXISTING_IMAGE" == "${PRODUCT_IMAGE_ORG}/kuma-cp:${DEBUG_IMAGE_TAG}" ]]; then
        return
    fi

    PATCH_TMP_FILE=$(mktemp)
    append_file $PATCH_TMP_FILE '['
    append_file $PATCH_TMP_FILE "{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/image\", \"value\":\"${PRODUCT_IMAGE_ORG}/kuma-cp:${DEBUG_IMAGE_TAG}\"}"

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
    if [[ ! -z "$EXISTING_RESOURCES" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/containers/0/resources"}'
    fi
    if [[ ! -z "$EXISTING_RUNAS_NONROOT" ]]; then
        append_file $PATCH_TMP_FILE ',{"op": "remove", "path": "/spec/template/spec/securityContext/runAsNonRoot"}'
    fi

    append_file $PATCH_TMP_FILE ',{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value":{"requests":{"memory":"1024Mi","cpu":1}}}'
    append_file $PATCH_TMP_FILE ',{"op": "add", "path": "/spec/template/spec/containers/0/command", "value":["sleep", "infinity"]}'

    append_file $PATCH_TMP_FILE ']'
    
    kubectl annotate namespace "${PRODUCT_NAME}-system" --overwrite kuma-cp-debug-image=${DEBUG_IMAGE_TAG}
    echo
    echo "******************"
    echo "You may use this command to rollback the debugger setup:"
    echo "    kubectl -n ${PRODUCT_NAME}-system rollout undo deployment/$DEPLOYMENT_NAME --to-revision=$CURRENT_REVISION"
    echo "******************"
    echo

    UPGRADED_RS_REVISION=$((CURRENT_REVISION+1))
    kubectl patch deploy $DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system --type json --patch-file "$PATCH_TMP_FILE"

    kubectl rollout status deploy/$DEPLOYMENT_NAME -n ${PRODUCT_NAME}-system
    sleep 5
}

function start_processes(){
    if [[ ! -z "$UPGRADED_RS_REVISION" ]]; then
        NEW_POD_TEMPLATE_HASH=$(kubectl get replicaset -l "app=${PRODUCT_NAME}-control-plane" -n "${PRODUCT_NAME}-system" -o json | jq -r ".items[] | select( .metadata.annotations[\"deployment.kubernetes.io/revision\"] == \"${UPGRADED_RS_REVISION}\") | .metadata.labels[\"pod-template-hash\"]")
        UPGRADED_CP_POD=$(kubectl get pods -l "app=${PRODUCT_NAME}-control-plane,pod-template-hash=$NEW_POD_TEMPLATE_HASH" -n "${PRODUCT_NAME}-system" --no-headers | grep Running | head -n 1 | awk '{print $1}')
    else
        UPGRADED_CP_POD=$(kubectl get pods -l "app=${PRODUCT_NAME}-control-plane" -n "${PRODUCT_NAME}-system" --no-headers | grep Running | head -n 1 | awk '{print $1}')
    fi
    if [[ -z "$UPGRADED_CP_POD" ]]; then
        echo "No control plane pod found in namespace '${PRODUCT_NAME}-system'"
        exit 1
    fi

    kubectl -n "${PRODUCT_NAME}-system" exec -c control-plane $UPGRADED_CP_POD -- mkdir -p /tmp/kuma-cp-debug/dlv
    EXISTING_DLV=$(kubectl -n "${PRODUCT_NAME}-system" exec -c control-plane $UPGRADED_CP_POD -- ls /tmp/kuma-cp-debug/dlv/dlv || return 0)
    if [[ -z "$EXISTING_DLV" ]]; then
        kubectl -n "${PRODUCT_NAME}-system" cp -c control-plane $SCRIPT_PATH/dlv/dlv-${GOLANG_VERSION}-${ARCH} $UPGRADED_CP_POD:/tmp/kuma-cp-debug/dlv/dlv
    fi
    kubectl -n "${PRODUCT_NAME}-system" cp -c control-plane $SCRIPT_PATH/dlv_config.yaml $UPGRADED_CP_POD:/tmp/kuma-cp-debug/dlv/config.yaml

    LOCAL_DBG_PORT=$(next_available_port 2345)
    kubectl -n "${PRODUCT_NAME}-system" port-forward pods/$UPGRADED_CP_POD ${LOCAL_DBG_PORT}:2345 &
    kubectl -n "${PRODUCT_NAME}-system" exec -c control-plane $UPGRADED_CP_POD  -- sh -c 'cd /tmp/kuma-cp-debug ; XDG_CONFIG_HOME=/tmp/kuma-cp-debug/ /tmp/kuma-cp-debug/dlv/dlv --listen=:2345 --headless=true --api-version=2 --accept-multiclient --log exec /usr/bin/kuma-cp -- run --log-level=info --log-output-path= --config-file=/etc/kuma.io/kuma-control-plane/config.yaml'
    kill -15 $(jobs -p) > /dev/null 2>&1 || true
}

prepare_global_vars
build_debug_image
prepare_dlv
load_debug_image_to_k3d
# todo: debug the current source code (without checkout to a tag!)
prepare_workload
start_processes