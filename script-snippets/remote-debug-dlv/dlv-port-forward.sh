#!/bin/bash


DEPLOYMENT_NAME=$1

echo "Trying to get pods of deployment $DEPLOYMENT_NAME..."
kubectl rollout status deploy $DEPLOYMENT_NAME

RS="$(kubectl describe deployment $DEPLOYMENT_NAME | grep '^NewReplicaSet' | awk '{print $2}')"
POD_HASH_LABEL="$(kubectl get rs $RS -o jsonpath='{.metadata.labels.pod-template-hash}')"
POD=$(kubectl get pods -l pod-template-hash=$POD_HASH_LABEL --show-labels | tail -n +2 | head -n 1 | awk '{print $1}')

echo "Setting up debugger to local port 2345..."
kubectl port-forward  pods/$POD 2345:2345

