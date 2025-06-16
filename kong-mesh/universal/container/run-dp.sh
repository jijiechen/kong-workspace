#!/bin/bash

if [[ "${RUN_MODE}" == "cp-only" ]]; then
    exit 0
fi

APP_NAME=${APP_NAME:-echo-server}
APP_PORT=${APP_PORT:-10011}
APP_PROTOCOL=${APP_PROTOCOL:-http}

CP_ADDRESS=127.0.0.1
PUBLIC_IP_ADDR=$(hostname -i)

if [[ "${WORKING_DIR}" == "" ]]; then
    WORKING_DIR=/tmp/${RANDOM}
    mkdir -p ${WORKING_DIR}
fi

if [[ "${RUN_MODE}" == "all-in-one" ]]; then
  until curl --connect-timeout 1  -s -o /dev/null --fail http://${CP_ADDRESS}:5681; do
    echo 'waiting for readiness of kuma-cp...'
    sleep 1
  done
  sleep 3

  kumactl config control-planes add --name cp --address http://${CP_ADDRESS}:5681 --config-file ${WORKING_DIR}/kumactl.config
  kumactl generate dataplane-token --tag "kuma.io/service=${APP_NAME}" --valid-for=87840h --config-file ${WORKING_DIR}/kumactl.config > ${WORKING_DIR}/dataplane-token
elif [[ "${RUN_MODE}" == "dp-only" ]]; then
    # todo: skip tls verify?
    # todo: check the token
    echo "error"
fi


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


# 5443: admission-server
# 5676: mads
# 5678: dp-server (xds)
# 5680: diagnostics
# 5681: http-api-server
# 5682: https-api-server

# this container needs to be run with --privileged or --caps NET_ADMIN,NET_RAW
kumactl install transparent-proxy --exclude-inbound-ports 5443,5676,5678,5680,5681,5682

runuser -u kuma-dp -- /usr/local/bin/kuma-dp run --transparent-proxy \
  --cp-address=https://${CP_ADDRESS}:5678 \
  --dataplane-token-file=${WORKING_DIR}/dataplane-token \
  --dataplane-file=${WORKING_DIR}/dataplane.yaml
