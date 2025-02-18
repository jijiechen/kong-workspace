#!/bin/bash


PROJ_NAME=$1


if [[ "$PROJ_NAME" == "" ]]; then
    PROJ_NAME=kuma
fi


kubectl -n ${PROJ_NAME}-system patch deployment/${PROJ_NAME}-control-plane --type json \
  --patch '[{"op":"replace", "path":"/spec/template/spec/containers/0/args/1", "value":"--log-level=debug"}]' 

kubectl -n ${PROJ_NAME}-system rollout status deployment/${PROJ_NAME}-control-plane