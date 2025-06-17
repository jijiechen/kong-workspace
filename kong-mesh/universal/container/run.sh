#!/bin/bash

if [[ "${DEBUG}" == "true" ]]; then
  set -x
fi

# RUN_MODE: all/cp/app/gateway/egress/ingress
RUN_MODE=${RUN_MODE:-all}
APP_CMD=${APP_CMD:-/kuma/run-app.sh}

APP_PORT=${APP_PORT:-10011}
APP_PROTOCOL=${APP_PROTOCOL:-http}
APP_NAME=${APP_NAME}

if [[ "${APP_NAME}" == "" ]]; then
  if [[ "${RUN_MODE}" == "all" ]]; then
    APP_NAME=echo-server
  else
    APP_NAME="${RUN_MODE}-$(uname -n)"
  fi
fi

WORKING_DIR=/tmp/${RANDOM}
mkdir -p ${WORKING_DIR}

if [[ "${APP_CMD}" != "none" ]]; then
  APP_NAME=${APP_NAME} APP_PORT=${APP_PORT} APP_PROTOCOL=${APP_PROTOCOL} RUN_MODE=${RUN_MODE} ${APP_CMD} &
fi
APP_NAME=${APP_NAME} APP_PORT=${APP_PORT} APP_PROTOCOL=${APP_PROTOCOL} RUN_MODE=${RUN_MODE} WORKING_DIR=${WORKING_DIR} /kuma/run-dp.sh &
WORKING_DIR=${WORKING_DIR} RUN_MODE=${RUN_MODE} /kuma/run-cp.sh &

if [[ "${RUN_MODE}" == "cp" ]]; then
  until curl --connect-timeout 1  -s -o /dev/null -k --fail https://127.0.0.1:5682/global-secrets/admin-user-token; do
    echo 'waiting for readiness of kuma-cp...'
    sleep 1
  done

  sleep 1
  echo "===== CP_TOKEN ====="
  curl -s -o - -k --fail https://127.0.0.1:5682/global-secrets/admin-user-token | grep data | cut -d '"' -f 4 | base64 -d
  echo ""
fi


function exit_all {
    kill -15 $(jobs -p) > /dev/null 2>&1 || true
}

trap exit_all EXIT INT QUIT TERM

sleep infinity
