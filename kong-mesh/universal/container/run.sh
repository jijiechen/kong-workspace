#!/bin/bash

RUN_MODE=all-in-one
WORKING_DIR=/tmp/${RANDOM}
mkdir -p ${WORKING_DIR}

WORKING_DIR=${WORKING_DIR} RUN_MODE=${RUN_MODE} /kuma/run-cp.sh &
WORKING_DIR=${WORKING_DIR} RUN_MODE=${RUN_MODE} /kuma/run-dp.sh &
# todo: start the app on port

function exit_all {
    kill -15 $(jobs -p) > /dev/null 2>&1 || true
}

trap exit_all EXIT INT QUIT TERM


cat
