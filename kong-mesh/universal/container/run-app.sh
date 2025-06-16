#!/bin/bash

# RUN_MODE: all-in-one/dp-only/cp-only
if [[ "${RUN_MODE}" == "cp-only" ]]; then
    exit 0
fi

SERVICE_NAME=${SERVICE_NAME:-echo-server}
SERVICE_PORT=${SERVICE_PORT:-10011}
SERVICE_PROTOCOL=${SERVICE_PROTOCOL:-http}

CMD=echo
IP_ARG='--ip 127.0.0.1'

if [[ "${SERVICE_PROTOCOL}" == "tcp" ]]; then
    CMD='healthcheck tcp'
    IP_ARG=''
fi
if [[ "${SERVICE_PROTOCOL}" == "grpc" ]]; then
    CMD='grpc server'
    IP_ARG=''
fi

testserver ${CMD} ${IP_ARG} --port ${SERVICE_PORT}
