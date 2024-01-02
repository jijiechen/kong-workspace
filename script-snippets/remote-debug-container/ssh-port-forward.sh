#!/bin/bash


DEPLOYMENT_NAME=$1
LOCAL_PORT=$2

echo "Trying to get pods of deployment $DEPLOYMENT_NAME..."
kubectl rollout status deploy $DEPLOYMENT_NAME

RS="$(kubectl describe deployment $deployment | grep '^NewReplicaSet' | awk '{print $2}')"
POD_HASH_LABEL="$(kubectl get rs $RS -o jsonpath='{.metadata.labels.pod-template-hash}')"
POD=$(kubectl get pods -l pod-template-hash=$POD_HASH_LABEL --show-labels | tail -n +2 | head -n 1 | awk '{print $1}')

echo "Setting up port forward for pod $POD to local port $LOCAL_PORT..."
ssh-keygen -R "[127.0.0.1]:$LOCAL_PORT" > /dev/null 2>&1
kubectl port-forward  pods/$POD $LOCAL_PORT:22

