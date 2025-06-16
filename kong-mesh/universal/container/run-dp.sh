#!/bin/bash

SERVICE_NAME=echo-server
SERVICE_PORT=10011
SERVICE_PROTOCOL=http

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
  kumactl generate dataplane-token --tag "kuma.io/service=${SERVICE_NAME}" --valid-for=87840h --config-file ${WORKING_DIR}/kumactl.config > ${WORKING_DIR}/dataplane-token
elif [[ "${RUN_MODE}" == "dp-only" ]]; then
    # todo: skip tls verify?
    # todo: check the token
    echo "error"
fi


cat << EOF > ${WORKING_DIR}/dataplane.yaml
type: Dataplane
mesh: default
name: ${SERVICE_NAME}
networking: 
  address: ${PUBLIC_IP_ADDR}
  inbound: 
    - port: ${SERVICE_PORT}
      servicePort: ${SERVICE_PORT}
      serviceAddress: 127.0.0.1
      tags: 
        kuma.io/service: ${SERVICE_NAME}
        kuma.io/protocol: ${SERVICE_PROTOCOL}
  admin:
    port: 9901
EOF


# 5443: admission-server
# 5676: mads
# 5678: dp-server (xds)
# 5680: diagnostics
# 5681: http-api-server
# 5682: https-api-server
kumactl install transparent-proxy --exclude-inbound-ports 5443,5676,5678,5680,5681,5682

runuser -u kuma-dp -- /usr/local/bin/kuma-dp run --transparent-proxy \
  --cp-address=https://${CP_ADDRESS}:5678 \
  --dataplane-token-file=${WORKING_DIR}/dataplane-token \
  --dataplane-file=${WORKING_DIR}/dataplane.yaml
