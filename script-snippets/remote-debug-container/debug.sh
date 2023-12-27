#!/bin/bash

set -e
# set -x

DEPLOYMENT_NAME=$1
CONTAINER_NAME=$2

DEPLOY_JSON_FILE=$(mktemp)

if [[ "$CONTAINER_NAME" == "RESTORE_BACKUP" ]]; then
    if [[ ! -z "$(kubectl get configmap remote-debug-backup-$DEPLOYMENT_NAME -o Name || true)" ]]; then
        kubectl get configmap remote-debug-backup-$DEPLOYMENT_NAME -o 'jsonpath={.data.json}' > $DEPLOY_JSON_FILE
        cat $DEPLOY_JSON_FILE | \
            jq -rc 'del(.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"]) | 
                del(.metadata.generation) 
                | del(.metadata.resourceVersion)' | kubectl apply -f -
        kubectl delete configmap remote-debug-backup-$DEPLOYMENT_NAME
        exit 0
    fi

    >&2 echo "No backup for deployment '$DEPLOYMENT_NAME' found"
    exit 1
fi


CONTAINER_JSON=
kubectl get deploy $DEPLOYMENT_NAME -o json > $DEPLOY_JSON_FILE
if [[ -z "$(head -n 1 $DEPLOY_JSON_FILE)" ]]; then
    >&2 echo "Deployment '$DEPLOYMENT_NAME' not found"
    exit 1
fi

if [[ -z "$CONTAINER_NAME" ]]; then
    CONTAINER_JSON=$(jq -rc ".spec.template.spec.containers[0] //empty" $DEPLOY_JSON_FILE)
else
    CONTAINER_JSON=$(jq -rc ".spec.template.spec.containers[] | select(name=\"$CONTAINER_NAME\") //empty" $DEPLOY_JSON_FILE)
fi

if [[ -z "$CONTAINER_JSON" ]]; then
    >&2 echo "Container '$CONTAINER_NAME' not found in deployment $DEPLOYMENT_NAME"
    exit 1
fi
CONTAINER_NAME=$(echo $CONTAINER_JSON | jq -rc '.name')
CONTAINER_IDX=$(jq -rc ".spec.template.spec.containers | map(.name == \"$CONTAINER_NAME\") | index(true)" $DEPLOY_JSON_FILE)

EXISTING_COMMAND=$(echo $CONTAINER_JSON | jq -rc '.command //empty')
EXISTING_ARGS=$(echo $CONTAINER_JSON | jq -rc '.args //empty')
EXISTING_PROBE_STARTUP=$(echo $CONTAINER_JSON | jq -rc '.startupProbe //empty')
EXISTING_PROBE_LIVENESS=$(echo $CONTAINER_JSON | jq -rc '.livenessProbe //empty')
EXISTING_PROBE_READINESS=$(echo $CONTAINER_JSON | jq -rc '.readinessProbe //empty')
EXISTING_RUNAS_NONROOT=$(cat $DEPLOY_JSON_FILE | jq -rc '.spec.template.spec.securityContext.runAsNonRoot //empty')
EXISTING_VOLUMES=$(cat $DEPLOY_JSON_FILE | jq -rc '.spec.template.spec.volumes //empty')
EXISTING_VOLUMEMOUNTS=$(echo $CONTAINER_JSON | jq -rc '.volumeMounts //empty')

PATCH_JSON=''
function patch(){
    APPEND=$(echo $1 | sed "s;CONTAINER_IDX;$CONTAINER_IDX;")
    PATCH_JSON="${PATCH_JSON}${APPEND}"
}

patch '['
patch '{"op": "replace", "path": "/spec/template/spec/containers/CONTAINER_IDX/image", "value":"docker.io/library/devimage:golang-centos8-20231226"}'
if [[ ! -z "$EXISTING_COMMAND" ]]; then
    patch ',{"op": "remove", "path": "/spec/template/spec/containers/CONTAINER_IDX/command"}'
fi
if [[ ! -z "$EXISTING_ARGS" ]]; then
    patch ',{"op": "remove", "path": "/spec/template/spec/containers/CONTAINER_IDX/args"}'
fi
if [[ ! -z "$EXISTING_PROBE_STARTUP" ]]; then
    patch ',{"op": "remove", "path": "/spec/template/spec/containers/CONTAINER_IDX/startupProbe"}'
fi
if [[ ! -z "$EXISTING_PROBE_LIVENESS" ]]; then
    patch ',{"op": "remove", "path": "/spec/template/spec/containers/CONTAINER_IDX/livenessProbe"}'
fi
if [[ ! -z "$EXISTING_PROBE_READINESS" ]]; then
    patch ',{"op": "remove", "path": "/spec/template/spec/containers/CONTAINER_IDX/readinessProbe"}'
fi
if [[ ! -z "$EXISTING_RUNAS_NONROOT" ]]; then
    patch ',{"op": "remove", "path": "/spec/template/spec/securityContext/runAsNonRoot"}'
fi
if [[ ! -z "$EXISTING_VOLUMES" ]]; then
    patch ',{"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "remote-debug-ssh-host", "emptyDir":{"medium": "Memory"}}}'
    patch ',{"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"name": "remote-debug-vscode", "emptyDir":{}}}'
else
    patch ',{"op": "add", "path": "/spec/template/spec/volumes", "value": [ {"name": "remote-debug-ssh-host", "emptyDir":{"medium": "Memory"}}, {"name": "remote-debug-vscode", "emptyDir":{}} ]}'
fi

if [[ ! -z "$EXISTING_VOLUMEMOUNTS" ]]; then
    patch ',{"op": "add", "path": "/spec/template/spec/containers/CONTAINER_IDX/volumeMounts/-", "value": {"name": "remote-debug-ssh-host", "mountPath":"/root/.ssh/host"}}'
    patch ',{"op": "add", "path": "/spec/template/spec/containers/CONTAINER_IDX/volumeMounts/-", "value": {"name": "remote-debug-vscode", "mountPath":"/root/.vscode-server"}}'
else
    patch ',{"op": "add", "path": "/spec/template/spec/containers/CONTAINER_IDX/volumeMounts", "value": [{"name": "remote-debug-ssh-host", "mountPath":"/root/.ssh/host"},{"name": "remote-debug-vscode", "mountPath":"/root/.vscode-server"}]}'
fi
patch ']'

if [[ -z "$(kubectl get configmap remote-debug-backup-$DEPLOYMENT_NAME -o Name || true)" ]]; then
    kubectl create configmap remote-debug-backup-$DEPLOYMENT_NAME --from-file json=$DEPLOY_JSON_FILE
fi
kubectl patch deploy $DEPLOYMENT_NAME --type json --patch "$PATCH_JSON"

