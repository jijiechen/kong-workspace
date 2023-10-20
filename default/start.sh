#!/bin/bash


# brew install multipass
multipass launch focal --name default \
    --cpus 4 --disk 80G --memory 8G \
    --mount /Users/jaychen:/opt/host \
    --mount /Users/jaychen/.ssh:/home/jaychen/.ssh \
    --cloud-init ./cloud-init.yaml

