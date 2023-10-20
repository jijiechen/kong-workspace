#!/bin/bash


set -e 



WORKING_DIR=$(mktemp)
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

rm $WORKING_DIR
mkdir -p $WORKING_DIR
cp ./cloud-init.yaml $WORKING_DIR/cloud-init.yaml

cp $WORKING_DIR/cloud-init.yaml $WORKING_DIR/cloud-init.yaml.pre ; sed "s;SSH_PUBLIC_KEY;${SSH_PUBLIC_KEY};g" $WORKING_DIR/cloud-init.yaml.pre > $WORKING_DIR/cloud-init.yaml
cp $WORKING_DIR/cloud-init.yaml $WORKING_DIR/cloud-init.yaml.pre ; sed "s;VM_USERNAME;${USER};g" $WORKING_DIR/cloud-init.yaml.pre > $WORKING_DIR/cloud-init.yaml


# brew install multipass
multipass launch focal --name default \
    --cpus 4 --disk 80G --memory 8G \
    --mount /Users/jaychen:/opt/host \
    --timeout 600 --cloud-init $WORKING_DIR/cloud-init.yaml

