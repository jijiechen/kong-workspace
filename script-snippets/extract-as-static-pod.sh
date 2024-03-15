#!/bin/bash

# extract-as-static-pod.sh pod.yaml > static-pod.yaml
# build a static pod that has kuma-sidecar from an injected pod

yq 'del(.status) |
del(.metadata.labels.pod-template-hash) |
del(.metadata.creationTimestamp) |
del(.metadata.resourceVersion) |
del(.metadata.uid) |
del(.metadata.generateName) |
del(.metadata.ownerReferences) |
del(.spec.tolerations) |
del(.spec.schedulerName) |
del(.spec.nodeName) |
del(.spec.volumes[] | select(.name | contains("kube-api-access-"))) |
.__c = .spec.containers  | .__c |= array_to_map | delpaths([.__c.*.volumeMounts[] | select( .name | contains("kube-api-access-")) | path]) | .spec.containers = [.__c.*] | del(.__c)  |
.__c = .spec.initContainers  | .__c |= array_to_map | delpaths([.__c.*.volumeMounts[] | select( .name | contains("kube-api-access-")) | path]) | .spec.initContainers = [.__c.*] | del(.__c) |
. ' "$@"
