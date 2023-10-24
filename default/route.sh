#!/bin/bash

set -e 

VM_NAME=${MULTIPASS_VM_NAME:-default}

echo "Adding route rules for vm '$VM_NAME'..."

HOST_IP=$(multipass ls --format=json | jq -r ".list[] | select(.name == \"$VM_NAME\") | .ipv4 | .[] | select( . | startswith(\"192.168.\"))")
if [ -z "$HOST_IP" ]; then
    echo "Could not determine vm IP address, try again later."
    exit 1
fi
echo "Adding route to nodes in kind..."

BRIDGE_IPS=$(multipass ls --format=json | jq -r ".list[] | select(.name == \"$VM_NAME\") | .ipv4 | .[] | select( . | startswith(\"172.\"))")

for IP in $BRIDGE_IPS; do
    echo "Adding route to $IP..."
    sudo route add $IP/16 $HOST_IP

    multipass exec $VM_NAME -- sudo iptables -t filter -A FORWARD -d $IP/16 -j ACCEPT
    multipass exec $VM_NAME -- sudo iptables -t nat -A POSTROUTING -d $IP/16 -j MASQUERADE
done

echo "Done."
