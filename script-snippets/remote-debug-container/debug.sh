#!/bin/bash

set -e
# set -x

DEPLOYMENT_NAME=$1
CONTAINER_NAME=$2
# --mount-ssh-keys
MOUNT_SSH_KEYS=$3

DEPLOY_JSON_FILE=$(mktemp)

if [[ "$@" == *"RESTORE_BACKUP"* ]]; then
    if [[ ! -z "$(kubectl get configmap remote-debug-backup-$DEPLOYMENT_NAME -o Name || true)" ]]; then
        kubectl delete secret local-ssh-keys 2> /dev/null || true
        kubectl get configmap remote-debug-backup-$DEPLOYMENT_NAME -o 'jsonpath={.data}' > $DEPLOY_JSON_FILE

        RESTORE_PATCH='[{"op": "replace", "path": "/spec/template/spec/volumes", "value":VOLUMES_JSON},
            {"op": "replace", "path": "/spec/template/spec/securityContext", "value":SECURITY_CONTEXT_JSON},
            {"op": "replace", "path": "/spec/template/spec/containers/CONTAINER_IDX", "value":CONTAINER_JSON}]'
        
        CONTAINER_IDX=$(jq -rc '.container_idx' $DEPLOY_JSON_FILE)

        RESTORE_PATCH_JSON=$(echo "$RESTORE_PATCH" | \
            sed "s;CONTAINER_IDX;$CONTAINER_IDX;" | \
            sed "s;VOLUMES_JSON;$(jq -rc '.deploy_json | fromjson | .spec.template.spec.volumes' $DEPLOY_JSON_FILE);" | \
            sed "s;SECURITY_CONTEXT_JSON;$(jq -rc '.deploy_json | fromjson | .spec.template.spec.securityContext' $DEPLOY_JSON_FILE);" | \
            sed "s;CONTAINER_JSON;$(jq -rc ".deploy_json | fromjson | .spec.template.spec.containers[$CONTAINER_IDX]" $DEPLOY_JSON_FILE);" | \
        jq -c)

        kubectl patch deploy $DEPLOYMENT_NAME --type json --patch "$RESTORE_PATCH_JSON"
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
    CONTAINER_JSON=$(jq -rc ".spec.template.spec.containers[] | select(.name==\"$CONTAINER_NAME\") //empty" $DEPLOY_JSON_FILE)
fi

if [[ -z "$CONTAINER_JSON" ]]; then
    >&2 echo "Container '$CONTAINER_NAME' not found in deployment $DEPLOYMENT_NAME"
    exit 1
fi
CONTAINER_NAME=$(echo $CONTAINER_JSON | jq -rc '.name')
CONTAINER_IMAGE=$(echo $CONTAINER_JSON | jq -rc '.image')
CONTAINER_IDX=$(jq -rc ".spec.template.spec.containers | map(.name == \"$CONTAINER_NAME\") | index(true)" $DEPLOY_JSON_FILE)

if [[ "$CONTAINER_IMAGE" == *"devimage"* ]]; then
    echo "The pod is already running a remote debug container."
    exit 0
fi

EXISTING_COMMAND=$(echo $CONTAINER_JSON | jq -rc '.command //empty')
EXISTING_ARGS=$(echo $CONTAINER_JSON | jq -rc '.args //empty')
EXISTING_PROBE_STARTUP=$(echo $CONTAINER_JSON | jq -rc '.startupProbe //empty')
EXISTING_PROBE_LIVENESS=$(echo $CONTAINER_JSON | jq -rc '.livenessProbe //empty')
EXISTING_PROBE_READINESS=$(echo $CONTAINER_JSON | jq -rc '.readinessProbe //empty')
EXISTING_RUNAS_NONROOT=$(cat $DEPLOY_JSON_FILE | jq -rc '.spec.template.spec.securityContext.runAsNonRoot //empty')
EXISTING_VOLUMES=$(cat $DEPLOY_JSON_FILE | jq -rc '.spec.template.spec.volumes //empty')
EXISTING_VOLUMEMOUNTS=$(echo $CONTAINER_JSON | jq -rc '.volumeMounts //empty')

PATCH_JSON=$(mktemp)
function patch(){
    APPEND=$(echo $1 | sed "s;CONTAINER_IDX;$CONTAINER_IDX;")
    echo -n ${APPEND} >> $PATCH_JSON
}

patch '['
patch '{"op": "replace", "path": "/spec/template/spec/containers/CONTAINER_IDX/image", "value":"jijiechen/remote-vscode:golang-centos8-20240102"}'
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

ALL_VOLUMES='[
        {"name": "remote-debug-ssh-host", "emptyDir":{"medium": "Memory"}},
        {"name": "remote-debug-vscode", "emptyDir":{}},
        {"name": "remote-debug-go-root", "emptyDir":{}},
        {"name": "remote-debug-kuma-dev", "emptyDir":{}},
        {"name": "remote-debug-cache-dir", "emptyDir":{}}
]'
ALL_VOLUME_MOUNTS='[
        {"name": "remote-debug-ssh-host", "mountPath":"/root/.ssh/host"},
        {"name": "remote-debug-vscode", "mountPath":"/root/.vscode-server"},
        {"name": "remote-debug-go-root", "mountPath":"/root/go"},
        {"name": "remote-debug-kuma-dev", "mountPath":"/root/.kuma-dev"},
        {"name": "remote-debug-cache-dir", "mountPath":"/root/.cache"}
]'
if [[ "$MOUNT_SSH_KEYS" == "--mount-ssh-keys" ]] && [[ -f "$HOME/.ssh/id_rsa" ]]; then
    ALL_VOLUMES=$(echo "$ALL_VOLUMES" | jq -rc '. += [ {"name": "remote-debug-ssh-keys", "secret":{"secretName": "local-ssh-keys", "defaultMode": 256}} ]')
    ALL_VOLUME_MOUNTS=$(echo "$ALL_VOLUME_MOUNTS" | jq -rc '. += [ {"name": "remote-debug-ssh-keys", "mountPath":"/root/.ssh/id_rsa", subPath: "id_rsa"},{"name": "remote-debug-ssh-keys", "mountPath":"/root/.ssh/authorized_keys", subPath: "id_rsa.pub"},{"name": "remote-debug-ssh-keys", "mountPath":"/root/.ssh/id_rsa.pub", subPath: "id_rsa.pub"} ]')
fi

if [[ ! -z "$EXISTING_VOLUMES" ]]; then
    echo "$ALL_VOLUMES" | jq -c '.[]' | while read VOLUME; do
        patch ',{"op": "add", "path": "/spec/template/spec/volumes/-", "value": '
        patch $VOLUME
        patch '}'
    done
else
    patch ',{"op": "add", "path": "/spec/template/spec/volumes", "value":'
    patch $(echo "$ALL_VOLUMES" | jq -rc '.')
    patch '}'
fi

if [[ ! -z "$EXISTING_VOLUMEMOUNTS" ]]; then
    echo $ALL_VOLUME_MOUNTS | jq -c '.[]' | while read VOLUME_MOUNT; do
        patch ',{"op": "add", "path": "/spec/template/spec/containers/CONTAINER_IDX/volumeMounts/-", "value": '
        patch $VOLUME_MOUNT
        patch '}'
    done
else
    patch ',{"op": "add", "path": "/spec/template/spec/containers/CONTAINER_IDX/volumeMounts", "value":'
    patch $(echo "$ALL_VOLUME_MOUNTS" | jq -rc '.')
    patch '}'
fi

patch ']'

if [[ "$MOUNT_SSH_KEYS" == "--mount-ssh-keys" ]] && [[ -f "$HOME/.ssh/id_rsa" ]]; then
    if [[ -z "$(kubectl get secret local-ssh-keys -o Name || true)" ]]; then
        kubectl create secret generic local-ssh-keys --from-file=id_rsa=$HOME/.ssh/id_rsa --from-file=id_rsa.pub=$HOME/.ssh/id_rsa.pub
    fi
fi
if [[ -z "$(kubectl get configmap remote-debug-backup-$DEPLOYMENT_NAME -o Name || true)" ]]; then
    kubectl create configmap remote-debug-backup-$DEPLOYMENT_NAME --from-file deploy_json=$DEPLOY_JSON_FILE --from-literal container_idx=$CONTAINER_IDX
fi

# cat $PATCH_JSON
kubectl patch deploy $DEPLOYMENT_NAME --type json --patch-file "$PATCH_JSON"

