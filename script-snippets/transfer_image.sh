#!/bin/bash

# set -x

# export SSH_USERNAME=ubuntu
# export SSH_KEYFILE=~/.ssh/id_rsa.multipass
# example:
# ../../script-snippets/transfer_image.sh 192.168.64.4 \
#     kumahq/kuma-universal:0.0.0-preview.v0f0c481f0 \
#     kumahq/kuma-cni:0.0.0-preview.v0f0c481f0 \
#     kumahq/kuma-init:0.0.0-preview.v0f0c481f0 \
#     kumahq/kuma-dp:0.0.0-preview.v0f0c481f0 \
#     kumahq/kuma-cp:0.0.0-preview.v0f0c481f0 \
#     kumahq/kumactl:0.0.0-preview.v0f0c481f0

SSH_SERVER="$1"
SSH_USER="${SSH_USERNAME}"
if [[ -z "$SSH_USER" ]]; then
    SSH_USER=$USER
fi
SSH_KEY="${SSH_KEYFILE}"
if [[ -z "$SSH_KEY" ]]; then
    SSH_KEY=~/.ssh/id_rsa
fi


IMAGE_DIRECTORY_REMOTE=/tmp/$RANDOM
echo "Creating $IMAGE_DIRECTORY_REMOTE on server"
ssh -i ${SSH_KEY} "${SSH_USER}@${SSH_SERVER}" "mkdir -p $IMAGE_DIRECTORY_REMOTE"

# all argument other than the first one are image names
shift
for IMAGE in "$@"
do
    FILE=$(echo $IMAGE | tr '/' '_' | tr ':' '_')
    echo "Transfering ${IMAGE}..."
    docker save -o "${FILE}.tar" "${IMAGE}"
    scp -i ${SSH_KEY} "${FILE}.tar" "${SSH_USER}@${SSH_SERVER}:$IMAGE_DIRECTORY_REMOTE/"

    ssh -i ${SSH_KEY} "${SSH_USER}@${SSH_SERVER}" "cd $IMAGE_DIRECTORY_REMOTE && docker load -i ${FILE}.tar"
    ssh -i ${SSH_KEY} "${SSH_USER}@${SSH_SERVER}" "cd $IMAGE_DIRECTORY_REMOTE && sudo k3s ctr images import ${FILE}.tar"

    rm "${FILE}.tar"
done


ssh -i ${SSH_KEY} "${SSH_USER}@${SSH_SERVER}" "rm -rf $IMAGE_DIRECTORY_REMOTE"