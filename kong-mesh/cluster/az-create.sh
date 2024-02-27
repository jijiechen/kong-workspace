#!/bin/bash

# make sure you are logged in and have kubectl/kubelogin installed:
# az aks install-cli

CLUSTER_NAME=poc
REGION=eastasia
NUM_NODES=1

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

az group create --name ${CLUSTER_NAME}_group --location $REGION
az aks create \
  --resource-group ${CLUSTER_NAME}_group \
  --name ${CLUSTER_NAME} \
  --location $REGION \
  --network-plugin=azure --network-plugin-mode=overlay \
  --max-pods 120 \
  --node-count $NUM_NODES --node-vm-size Standard_D4s_v3 --nodepool-name nodepool --node-os-upgrade-channel None --node-osdisk-size 40 \
  --enable-managed-identity --no-ssh-key \
  --k8s-support-plan KubernetesOfficial


az aks get-credentials --name $CLUSTER_NAME --file ~/.kube/az-$CLUSTER_NAME.config --resource-group ${CLUSTER_NAME}_group
az aks get-credentials --name $CLUSTER_NAME --context az_${REGION}_${CLUSTER_NAME} --resource-group ${CLUSTER_NAME}_group

# kubectl config use-context az_${REGION}_${CLUSTER_NAME}

# for clusters with spot nodes:
# kubectl delete ValidatingWebhookConfiguration aks-node-validating-webhook
# kubectl taint nodes aks-nodepool-58664372-vmss000000 kubernetes.azure.com/scalesetpriority=spot:NoSchedule-