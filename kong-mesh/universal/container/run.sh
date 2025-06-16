#!/bin/bash

# RUN_MODE: all-in-one/dp-only/cp-only
RUN_MODE=${RUN_MODE:-all-in-one}
APP_CMD=${APP_CMD:-/kuma/run-app.sh}
APP_NAME=${APP_NAME:-echo-server}
APP_PORT=${APP_PORT:-10011}
APP_PROTOCOL=${APP_PROTOCOL:-http}

WORKING_DIR=/tmp/${RANDOM}
mkdir -p ${WORKING_DIR}

if [[ "${APP_CMD}" != "none" ]]; then
  APP_NAME=${APP_NAME} APP_PORT=${APP_PORT} APP_PROTOCOL=${APP_PROTOCOL} RUN_MODE=${RUN_MODE} ${APP_CMD} &
fi
APP_NAME=${APP_NAME} APP_PORT=${APP_PORT} APP_PROTOCOL=${APP_PROTOCOL} RUN_MODE=${RUN_MODE} WORKING_DIR=${WORKING_DIR} /kuma/run-dp.sh &
WORKING_DIR=${WORKING_DIR} RUN_MODE=${RUN_MODE} /kuma/run-cp.sh &

function exit_all {
    kill -15 $(jobs -p) > /dev/null 2>&1 || true
}

trap exit_all EXIT INT QUIT TERM

sleep infinity
