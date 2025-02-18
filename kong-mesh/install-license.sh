
#!/bin/bash

if [[ "$KMESH_LICENSE" == "" ]]; then
    >&2 echo "set Kong Mesh license file using environment variable KMESH_LICENSE"
    exit 1
fi

kubectl -n kong-mesh-system create secret generic kong-mesh-license --from-file license.json=$KMESH_LICENSE
kubectl -n kong-mesh-system patch deploy/kong-mesh-control-plane --type json \
  --patch '[{"op": "add", "path": "/spec/template/spec/containers/0/env/0", "value":{ "name": "KMESH_LICENSE_INLINE", "valueFrom": {"secretKeyRef": {"name": "kong-mesh-license", "key": "license.json"}}   }}]'

kubectl -n kong-mesh-system rollout status deployment/kong-mesh-control-plane