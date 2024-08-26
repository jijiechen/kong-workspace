#!/bin/bash

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

function install(){
  kubectl create namespace kuma-demo || true
  kubectl label ns/kuma-demo kuma.io/sidecar-injection=enabled --overwrite

  for i in `seq ${1} ${2} ${3}`; do
    sed "s/%/$i/g" $SCRIPT_PATH/httpbin-template.yaml | kubectl apply -n kuma-demo -f -
    sleep 2
  done
}

install 0 1 30