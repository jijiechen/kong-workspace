#!/bin/bash

PUB_KEY=$(cat ~/.ssh/id_rsa.pub | awk '{print $2}')
sed ./cloud-init.yaml 's/HOST_PUB_KEY//


# brew install multipass
multipass launch focal --name default \
    --cpus 4 --disk 80G --memory 8G \
    --mount /Users/jaychen:/opt/host \
    --mount /Users/jaychen/.ssh:/root/.ssh \
    --cloud-init ./cloud-init.yaml

