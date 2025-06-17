#!/bin/bash

if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi
if [[ "${RUN_MODE}" == "cp" ]]; then
    exit 0
fi

APP_NAME=${APP_NAME:-echo-server}
CP_HOST=${CP_HOST:-127.0.0.1} # x.y.z.w
# CP_TOKEN

APP_PORT=${APP_PORT:-10011}
APP_PROTOCOL=${APP_PROTOCOL:-http}

PUBLIC_IP_ADDR=$(hostname -i)

if [[ "${WORKING_DIR}" == "" ]]; then
    WORKING_DIR=/tmp/${RANDOM}
    mkdir -p ${WORKING_DIR}
fi

function generate_token(){
  if [[ "${RUN_MODE}" == "all" ]] || [[ "${RUN_MODE}" == "sidecar" ]] || [[ "${RUN_MODE}" == "gateway" ]]; then
    kumactl generate dataplane-token --tag "kuma.io/service=${APP_NAME}" --valid-for=87840h --config-file ${WORKING_DIR}/kumactl.config > ${WORKING_DIR}/dataplane-token
  elif [[ "${RUN_MODE}" == "ingress" ]]; then
    kumactl generate zone-token --valid-for=87840h --scope ingress --config-file ${WORKING_DIR}/kumactl.config > ${WORKING_DIR}/dataplane-token
  elif [[ "${RUN_MODE}" == "egress" ]]; then
    kumactl generate zone-token --zone default --valid-for=87840h --scope egress --config-file ${WORKING_DIR}/kumactl.config > ${WORKING_DIR}/dataplane-token
  fi
}


function generate_dataplane_file(){
  if [[ "${RUN_MODE}" == "gateway" ]]; then
cat << EOF > ${WORKING_DIR}/dataplane.yaml
type: Dataplane
mesh: default
name: ${APP_NAME}
networking:
  address: ${PUBLIC_IP_ADDR}
  gateway:
    type: BUILTIN
    tags:
      kuma.io/service: ${APP_NAME}
  admin:
    port: 9901
EOF
  elif [[ "${RUN_MODE}" == "ingress" ]]; then
cat << EOF > ${WORKING_DIR}/dataplane.yaml
type: ZoneIngress
name: ${APP_NAME}
networking:
  address: ${PUBLIC_IP_ADDR}
  port: 10001
  advertisedAddress: ${PUBLIC_IP_ADDR} # Adapt to the address of the Load Balancer in front of your ZoneIngresses
  advertisedPort: 10001 # Adapt to the port of the Load Balancer in front of you ZoneIngresses
  admin:
    port: 9901
EOF
  elif [[ "${RUN_MODE}" == "egress" ]]; then
cat << EOF > ${WORKING_DIR}/dataplane.yaml
type: ZoneEgress
name: ${APP_NAME}
networking:
  address: ${PUBLIC_IP_ADDR}
  port: 10002
  admin:
    port: 9901
EOF
  else
cat << EOF > ${WORKING_DIR}/dataplane.yaml
type: Dataplane
mesh: default
name: ${APP_NAME}
networking: 
  address: ${PUBLIC_IP_ADDR}
  inbound: 
    - port: ${APP_PORT}
      servicePort: ${APP_PORT}
      serviceAddress: 127.0.0.1
      tags: 
        kuma.io/service: ${APP_NAME}
        kuma.io/protocol: ${APP_PROTOCOL}
  admin:
    port: 9901
EOF
  fi
}

function get_proxy_type() {
  if [[ "${RUN_MODE}" == "gateway" ]]; then
    echo "dataplane"
  elif [[ "${RUN_MODE}" == "ingress" ]]; then
    echo "ingress"
  elif [[ "${RUN_MODE}" == "egress" ]]; then
    echo "egress"
  else
    echo "dataplane"
  fi
}


until curl --connect-timeout 1  -s -o /dev/null -k --fail https://${CP_HOST}:5682; do
  echo 'waiting for readiness of kuma-cp...'
  sleep 1
done

if [[ "${RUN_MODE}" == "all" ]]; then
  sleep 3
  kumactl config control-planes add --name cp --address http://127.0.0.1:5681 --config-file ${WORKING_DIR}/kumactl.config
else
  if [[ "${CP_TOKEN}" == "" ]]; then
    >&2 printf "Please specify CP_TOKEN environment variable\n"
    exit 1
  fi

  kumactl config control-planes add --name cp --address https://${CP_HOST}:5682 --skip-verify --auth-type=tokens --auth-conf "token=${CP_TOKEN}" --config-file ${WORKING_DIR}/kumactl.config
fi

generate_token
generate_dataplane_file


DP_ARGS=''
PROXY_TYPE=$(get_proxy_type)

if [[ "${RUN_MODE}" == "all" ]] || [[ "${RUN_MODE}" == "sidecar" ]]; then
  DP_ARGS='--transparent-proxy'

  # 5443: admission-server
  # 5676: mads
  # 5678: dp-server (xds)
  # 5680: diagnostics
  # 5681: http-api-server
  # 5682: https-api-server

  # this container needs to be run with --privileged or --caps NET_ADMIN,NET_RAW
  kumactl install transparent-proxy --exclude-inbound-ports 5443,5676,5678,5680,5681,5682
else
  DP_ARGS='--dns-enabled=false'
fi

LOG_LEVEL=info
if [[ "${DEBUG}" == "true" ]]; then
    LOG_LEVEL=debug
    DP_ARGS="${DP_ARGS} --dns-enable-logging"
fi

runuser -u kuma-dp -- /usr/local/bin/kuma-dp run --proxy-type ${PROXY_TYPE} ${DP_ARGS} \
  --cp-address=https://${CP_HOST}:5678 \
  --dataplane-token-file=${WORKING_DIR}/dataplane-token \
  --dataplane-file=${WORKING_DIR}/dataplane.yaml \
  --log-level ${LOG_LEVEL} --envoy-log-level ${LOG_LEVEL}
