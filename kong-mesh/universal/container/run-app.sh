#!/bin/bash


if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi

if [[ "${RUN_MODE}" != "all" ]] && [[ "${RUN_MODE}" != "sidecar" ]]; then
  exit 0
fi

APP_NAME=${APP_NAME:-echo-server}
APP_PORT=${APP_PORT:-10011}
APP_PROTOCOL=${APP_PROTOCOL:-http}

CMD=echo
IP_ARG='--ip 127.0.0.1'

if [[ "${APP_PROTOCOL}" == "tcp" ]]; then
    CMD='healthcheck tcp'
    IP_ARG=''
fi
if [[ "${APP_PROTOCOL}" == "grpc" ]]; then
    CMD='grpc server'
    IP_ARG=''
fi

testserver ${CMD} ${IP_ARG} --port ${APP_PORT}
