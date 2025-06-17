#!/bin/bash

if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi
if [[ "${RUN_MODE}" != "all" ]] && [[ "${RUN_MODE}" != "cp" ]]; then
    exit 0
fi

if [[ "${WORKING_DIR}" == "" ]]; then
    WORKING_DIR=/tmp/${RANDOM}
    mkdir -p ${WORKING_DIR}
fi

LOG_LEVEL=info
if [[ "${DEBUG}" == "true" ]]; then
    LOG_LEVEL=debug
fi
KUMA_GENERAL_WORK_DIR=${WORKING_DIR} kuma-cp run --log-level ${LOG_LEVEL} --config-file /kuma/kuma-cp.conf

# 5443: admission-server
# 5676: mads
# 5678: dp-server (xds)
# 5680: diagnostics
# 5681: http-api-server
# 5682: https-api-server

