#!/bin/bash

# we can also use kumactl:
# kumactl generate tls-certificate --type server --key-file <key-out> --cert-file <cert-out> --hostname <name>
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if [ ! -d "$SCRIPT_PATH/mesh-infra" ]; then
    git clone https://github.com/jijiechen/mesh-infra.git $SCRIPT_PATH/mesh-infra
else
    (cd $SCRIPT_PATH/mesh-infra ; git pull)
fi

$SCRIPT_PATH/mesh-infra/certs/ca/gen.sh
$SCRIPT_PATH/mesh-infra/certs/server/gen.sh $1

cat server.pem ca.pem > tls.crt
mv ca.pem ca.crt
mv server.key tls.key