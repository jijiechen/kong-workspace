#!/bin/bash


CLUSTER_NAME=startup-task
REGION=eu-west-3
# ap-southeast-1
MACHINE_TYPE=c5.2xlarge
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



eksctl create cluster --name ${CLUSTER_NAME} --instance-prefix ${CLUSTER_NAME} \
  --region ${REGION} --node-type ${MACHINE_TYPE} \
  --nodes 2  --nodes-min 2  --nodes-max 2 \
  --managed --spot

  if [ $? -eq 0 ]
  then
    echo "Cluster Setup Completed with eksctl command."
  else
    echo "Cluster Setup Failed while running eksctl command."
  fi




# eksctl utils write-kubeconfig --cluster=ubuntu-starter-1
# jay.chen@konghq.com@ubuntu-starter-1.eu-west-3.eksctl.io


# eksctl create cluster --name jay-starter --instance-prefix jay-starter \
#   --region eu-west-3 --node-type c5.2xlarge \
#   --nodes 2  --nodes-min 2  --nodes-max 2 \
#   --managed --spot \
#   --kubeconfig --set-kubeconfig-context

