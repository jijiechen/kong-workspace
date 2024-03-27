#!/bin/bash

NS=$1

if [[ -z "$NS" ]]; then
    NS=$(kubectl config view --minify -o jsonpath='{..namespace}')
fi


SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
STATIC_POD_NAME=static-pod-$RANDOM

kubectl -n $NS get pods -o json \
 | jq 'first ( .items[] | select( .metadata.annotations["kuma.io/sidecar-injected"] == "true") )' \
 | $SCRIPT_PATH/extract-as-static-pod.sh \
 | yq -P ".metadata.name=\"$STATIC_POD_NAME\"
    | .metadata.labels.generated=\"true\"
    | .metadata.labels.static=\"true\"
    | del(.metadata.labels.app)
    | .spec.initContainers[0].securityContext.privileged=true
    | .spec.initContainers[0].securityContext.allowPrivilegeEscalation=true"