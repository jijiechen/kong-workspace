#!/bin/bash


CLUSTER_NAME=startup-task
REGION=europe-west1-c
MACHINE_TYPE=n1-standard-8
NUM_NODES=2

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      CLUSTER_NAME="$2"
      shift
      shift
      ;;
    --region)
      REGION="$2"
      shift 
      shift
      ;;
    --machine-type)
      MACHINE_TYPE="$2"
      shift
      shift
      ;;
    --nodes)
      NUM_NODES="$2"
      shift 
      shift
      ;;
    # -*|--*)
    #   echo "Unknown option $1"
    #   exit 1
    #   ;;
    *)
    #  POSITIONAL_ARGS+=("$1") 
      shift
      ;;
  esac
done




gcloud container clusters create ${CLUSTER_NAME} --num-nodes=${NUM_NODES} --zone ${REGION} --preemptible --machine-type ${MACHINE_TYPE}
gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${REGION}

