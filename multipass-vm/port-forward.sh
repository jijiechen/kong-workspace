#!/bin/bash

# port-forward.sh default 5681

VM_NAME=$1
PORT=$2

HOST_IP=$(multipass ls --format=json | jq -r ".list[] | select(.name == \"$VM_NAME\") | .ipv4 | .[] | select( . | startswith(\"192.168.\"))")
sudo ssh -i /var/root/Library/Application\ Support/multipassd/ssh-keys/id_rsa -NT -L "$PORT:localhost:$PORT" "ubuntu@$HOST_IP"
