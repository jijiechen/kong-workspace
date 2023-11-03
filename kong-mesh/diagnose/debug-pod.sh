#!/bin/bash

POD=$1
NS=$2


# an ephemeral container will be added
if [ -z "$NS" ]; then
    NS=$(kubectl config view --minify | grep 'namespace:' | awk '{print $2}')
fi

kubectl -n "$NS" debug -it --image quay.io/giantswarm/debug $POD

