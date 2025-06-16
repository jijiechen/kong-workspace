#!/bin/bash

# RUN_MODE: all-in-one/dp-only/cp-only

if [[ "${WORKING_DIR}" == "" ]]; then
    WORKING_DIR=/tmp/${RANDOM}
    mkdir -p ${WORKING_DIR}
fi

KUMA_GENERAL_WORK_DIR=${WORKING_DIR} kuma-cp run --log-level info --config-file /kuma/kuma-cp.conf

