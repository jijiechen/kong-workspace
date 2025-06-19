#!/bin/bash
# set -x

CONTAINER_CP=kuma-cp
CONTAINER_APP=kuma-app-sidecar
CONTAINER_GATEWAY=kuma-gateway
CONTAINER_EGRESS=kuma-egress

docker rm -f ${CONTAINER_CP} ${CONTAINER_APP} ${CONTAINER_GATEWAY} ${CONTAINER_EGRESS}

docker run -t -d --name ${CONTAINER_CP} --rm -e RUN_MODE=cp kuma-all-in-one:2.11.0
sleep 2

docker exec ${CONTAINER_CP}   /bin/bash -c 'until curl --connect-timeout 1  -s -o /dev/null -k --fail https://127.0.0.1:5682/global-secrets/admin-user-token; do sleep 1; done'
CP_HOST=$(docker inspect ${CONTAINER_CP} | jq -r '.[0].NetworkSettings.IPAddress')
CP_TOKEN=$(docker exec ${CONTAINER_CP} /bin/bash -c 'curl -s -o - -k --fail https://127.0.0.1:5682/global-secrets/admin-user-token' | grep data | cut -d '"' -f 4 | base64 -d)

docker run -t -d --rm --name ${CONTAINER_APP} --privileged -e RUN_MODE=app -e CP_HOST=${CP_HOST} -e "CP_TOKEN=$CP_TOKEN"  kuma-all-in-one:2.11.0
docker run -t -d --rm --name ${CONTAINER_GATEWAY} -e RUN_MODE=gateway -e CP_HOST=${CP_HOST} -e "CP_TOKEN=$CP_TOKEN" kuma-all-in-one:2.11.0
docker run -t -d --rm  --name ${CONTAINER_EGRESS} -e RUN_MODE=egress  -e CP_HOST=${CP_HOST} -e "CP_TOKEN=$CP_TOKEN"  kuma-all-in-one:2.11.0


SERVICE_NAME_APP=$(docker exec ${CONTAINER_APP} /bin/bash -c 'echo ${RUN_MODE}-$(uname -n)')
SERVICE_NAME_GATEWAY=$(docker exec ${CONTAINER_GATEWAY} /bin/bash -c 'echo ${RUN_MODE}-$(uname -n)')

kumactl config control-planes add --name universal --overwrite --address https://${CP_HOST}:5682 --skip-verify --auth-type=tokens --auth-conf "token=${CP_TOKEN}" --config-file ./kumactl.config
cat <<EOF | kumactl --config-file ./kumactl.config apply -f -
name: default
type: Mesh
mtls:
  backends:
  - name: ca-1
    type: builtin
  enabledBackend: ca-1
routing:
  zoneEgress: true
meshServices:
  mode: Exclusive
---

type: MeshTrafficPermission
name: allow-all
mesh: default
spec:
  targetRef:
    kind: Mesh
  from:
  - targetRef:
      kind: Mesh
    default:
      action: Allow

---
type: HostnameGenerator
name: external-services
mesh: default
spec:
  selector:
    meshExternalService:
      matchLabels:
        kuma.io/origin: zone
  template: "{{ .DisplayName }}.svc.external"

---
type: MeshExternalService
name: mes-http
mesh: default
spec:
  match:
    type: HostnameGenerator
    port: 80
    protocol: http
  endpoints:
  - address: httpbin.org
    port: 80
---

type: MeshGateway
mesh: default
name: edge-gateway
selectors:
  - match:
      kuma.io/service: ${SERVICE_NAME_GATEWAY}
conf:
  listeners:
    - port: 8080
      protocol: HTTP
      tags:
        port: http-8080
    - port: 8081
      protocol: HTTP
      tags:
        port: http-8081

---
type: MeshHTTPRoute
name: edge-gateway-8080-route
mesh: default
spec:
  targetRef:
    kind: MeshGateway
    name: edge-gateway
    tags:
      port: http-8080
  to:
  - targetRef:
      kind: Mesh
    rules:
    - matches:
      - path:
          type: PathPrefix
          value: "/"
      default:
        backendRefs:
        - kind: MeshService
          name: ${SERVICE_NAME_APP}

---
type: MeshHTTPRoute
name: edge-gateway-8081-route
mesh: default
spec:
  targetRef:
    kind: MeshGateway
    name: edge-gateway
    tags:
      port: http-8081
  to:
  - targetRef:
      kind: Mesh
    rules:
    - matches:
      - path:
          type: PathPrefix
          value: "/"
      default:
        backendRefs:
        - kind: MeshExternalService
          name: mes-http

---
type: MeshAccessLog
name: all-incoming-traffic
mesh: default
spec:
  rules:
  - default:
      backends:
      - type: File
        file:
          path: "/dev/stdout"
---
type: MeshAccessLog
name: all-outgoing-traffic
mesh: default
spec:
  to:
  - targetRef:
      kind: Mesh
    default:
      backends:
      - type: File
        file:
          path: "/dev/stdout"
EOF

kumactl get meshes  --config-file ./kumactl.config
