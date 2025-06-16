#!/bin/bash

# RUN_MODE: all-in-one/dp-only/cp-only

if [[ "${RUN_MODE}" == "dp-only" ]]; then
    exit 0
fi

if [[ "${WORKING_DIR}" == "" ]]; then
    WORKING_DIR=/tmp/${RANDOM}
    mkdir -p ${WORKING_DIR}
fi

KUMA_GENERAL_WORK_DIR=${WORKING_DIR} kuma-cp run --log-level info --config-file /kuma/kuma-cp.conf

# 5443: admission-server
# 5676: mads
# 5678: dp-server (xds)
# 5680: diagnostics
# 5681: http-api-server
# 5682: https-api-server

# how to connect to the CP? (get  a token)