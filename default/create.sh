#!/bin/bash


set -e 


VM_NAME=${MULTIPASS_VM_NAME:-default}

echo "Creating vm '$VM_NAME'..."

WORKING_DIR=$(mktemp)
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

rm $WORKING_DIR
mkdir -p $WORKING_DIR
cp ./cloud-init.yaml $WORKING_DIR/cloud-init.yaml

cp $WORKING_DIR/cloud-init.yaml $WORKING_DIR/cloud-init.yaml.pre ; sed "s;SSH_PUBLIC_KEY;${SSH_PUBLIC_KEY};g" $WORKING_DIR/cloud-init.yaml.pre > $WORKING_DIR/cloud-init.yaml
cp $WORKING_DIR/cloud-init.yaml $WORKING_DIR/cloud-init.yaml.pre ; sed "s;VM_USERNAME;${USER};g" $WORKING_DIR/cloud-init.yaml.pre > $WORKING_DIR/cloud-init.yaml


# brew install multipass
multipass launch focal --name $VM_NAME \
    --cpus 8 --disk 80G --memory 16G \
    --mount /Users/$USER:/opt/host \
    --timeout 600 --cloud-init $WORKING_DIR/cloud-init.yaml

 # multipass transfer ~/.ssh/id_rsa dev:/home/${USER}/.ssh/
 # multipass transfer ~/.ssh/id_rsa.pub dev:/home/${USER}/.ssh/
