#!/bin/bash

# port-forward.sh default 5681

VM_NAME=$1

HOST_IP=$(multipass ls --format=json | jq -r ".list[] | select(.name == \"$VM_NAME\") | .ipv4 | .[] | select( . | startswith(\"192.168.\"))")
sudo ssh -i /var/root/Library/Application\ Support/multipassd/ssh-keys/id_rsa -NT -L "$2:localhost:$2" "ubuntu@$HOST_IP"
