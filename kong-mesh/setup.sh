#!/bin/bash

# set -x
set -e

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
USERNAME=$(whoami)

CLOUD_PLATFORM=gcp
USAGE=starter

REGIONS_GCP=eu=europe-west1-c,asia=asia-east1-a
REGIONS_AWS=eu=eu-west-3,asia=ap-southeast-1
REGIONS=
GLOBAL_CONTEXT=
ZONE_CONTEXTS=

CREATE_CLUSTER=
INSTALL_CONTROL_PLANE=
MULTIZONE=
INSTALL_OBSERVABILITY=
INSTALL_DEMO=

while [[ $# -gt 0 ]]; do
  case $1 in
    --cloud)
      CLOUD_PLATFORM="$2"
      shift
      shift
      ;;
    --usage)
      USAGE="$2"
      shift
      shift
      ;;
    --username)
      USERNAME="$2"
      shift
      shift
      ;;
    --create-cluster)
      CREATE_CLUSTER=1
      shift
      ;;
    --control-plane)
      INSTALL_CONTROL_PLANE=1
      shift
      ;;
    --multizone)
      MULTIZONE=1
      shift
      ;;
    --multi-zone)
      MULTIZONE=1
      shift
      ;;
    --observability)
      INSTALL_OBSERVABILITY=1
      shift
      ;;
    --demo)
      INSTALL_DEMO=1
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


COLOR_RED='\033[1;31m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_NONE='\033[0m' # No Color

###################################################
# create clusters if needed 
###################################################
if [ "$CREATE_CLUSTER" == "1" ]; then
  if [ "$CLOUD_PLATFORM" == "k3d" ]; then
    $SCRIPT_PATH/cluster/k3d-create.sh --name ${USERNAME}-${USAGE}-1 --nodes 2

    GLOBAL_CONTEXT="k3d-${USERNAME}-${USAGE}-1"
    if [ "$MULTIZONE" == "1" ]; then
      ZONE_CONTEXTS="eu=k3d-${USERNAME}-${USAGE}-1,asia=k3d-${USERNAME}-${USAGE}-2"
      $SCRIPT_PATH/cluster/k3d-create.sh --name ${USERNAME}-${USAGE}-2 --nodes 2
    fi
  elif [ "$CLOUD_PLATFORM" == "gcp" ]; then
    # create the clusters...
    CUR_PROJECT=$(gcloud config get-value project)
    REGIONS="$REGIONS_GCP"
    REGION_1=$(echo -n $REGIONS | cut -d ',' -f 1 | cut -d '=' -f 2)
    REGION_2=$(echo -n $REGIONS | cut -d ',' -f 2 | cut -d '=' -f 2)

    GLOBAL_CONTEXT="gke_${CUR_PROJECT}_${REGION_1}_${USERNAME}-${USAGE}-1"
    $SCRIPT_PATH/cluster/gcp-create.sh --name ${USERNAME}-${USAGE}-1 --nodes 2 --region $REGION_1

    if [ "$MULTIZONE" == "1" ]; then
      ZONE_CONTEXTS="eu=gke_${CUR_PROJECT}_${REGION_1}_${USERNAME}-${USAGE}-1,asia=gke_${CUR_PROJECT}_${REGION_1}_${USERNAME}-${USAGE}-2"
      $SCRIPT_PATH/cluster/gcp-create.sh --name ${USERNAME}-${USAGE}-2 --nodes 2 --region $REGION_2
    fi
  elif [ "$CLOUD_PLATFORM" == "aws" ]; then
    # create the clusters...
    REGIONS="$REGIONS_AWS"
    REGION_1=$(echo -n $REGIONS | cut -d ',' -f 1 | cut -d '=' -f 2)
    REGION_2=$(echo -n $REGIONS | cut -d ',' -f 2 | cut -d '=' -f 2)

    GLOBAL_CONTEXT="gke_team-mesh_${REGION_1}_${USERNAME}-${USAGE}-1"
    $SCRIPT_PATH/cluster/aws-create.sh --name ${USERNAME}-${USAGE}-1 --nodes 2 --region $REGION_1

    if [ "$MULTIZONE" == "1" ]; then
      ZONE_CONTEXTS="eu=gke_team-mesh_${REGION_1}_${USERNAME}-${USAGE}-1,asia=gke_team-mesh_${REGION_1}_${USERNAME}-${USAGE}-2"
      $SCRIPT_PATH/cluster/aws-create.sh --name ${USERNAME}-${USAGE}-2 --nodes 2 --region $REGION_2
    fi
  else
    echo "${COLOR_RED}Unsupported cloud platform: ${CLOUD_PLATFORM}${COLOR_NONE}"
    exit 1
  fi

  echo "${COLOR_GREEN}===========================${COLOR_NONE}"
  echo "${COLOR_GREEN}Cluster installed complete.${COLOR_NONE}"
  echo "${COLOR_GREEN}===========================${COLOR_NONE}"
fi

###################################################
# install control planes if needed 
###################################################
if [ "$INSTALL_CONTROL_PLANE" == "1" ]; then
  GLOBAL_NS=kong-mesh-global
  ZONE_NS=kong-mesh-system

  if [ "$MULTIZONE" == "1" ]; then
      echo "Switching to global zone: $GLOBAL_CONTEXT"
      kubectl config use-context $GLOBAL_CONTEXT
      EXISTING_NAME=$(kubectl --namespace $GLOBAL_NS  get service/kong-mesh-global-zone-sync  -o  Name || true)
      if [ -z "$EXISTING_NAME" ]; then
          $SCRIPT_PATH/control-planes/global/install.sh "$GLOBAL_NS"
      else
        echo "Existing global control plane found in namespace $GLOBAL_NS"
      fi

      echo
      echo "Trying to get sync endpoint from global control plane..."

      TIMES_TRIED=0
      MAX_ALLOWED_TRIES=30
      until [ -n "$(kubectl --namespace $GLOBAL_NS  get service/kong-mesh-global-zone-sync  -o jsonpath='{.status.loadBalancer.ingress[*].ip}')" ]; do
          echo "Waiting for global control plane endpoint..." && sleep 2
          TIMES_TRIED=$((TIMES_TRIED+1))
          if [[ $TIMES_TRIED -ge $MAX_ALLOWED_TRIES ]]; then 
              echo "${COLOR_RED}Timeout waiting for endpoint IP of the global control plane.${COLOR_NONE}"
              exit 1
          fi
      done


      EXTERNAL_IP=$(kubectl --namespace $GLOBAL_NS  get service/kong-mesh-global-zone-sync  -o jsonpath='{.status.loadBalancer.ingress[*].ip}')
      if [ -z "$EXTERNAL_IP" ]; then
        echo "${COLOR_RED}Can not determine a public IP address for the sync endpoint from global control plane.${COLOR_NONE}"
        exit 1
      fi

      SYNC_ENDPOINT=${EXTERNAL_IP}:5685
      echo "${COLOR_GREEN}Zone sync endpoint in global Control Plane is:${COLOR_NONE}"
      echo "$SYNC_ENDPOINT"

      echo ''
      IFS=',' read -r -a ZONE_CTXS <<< "$ZONE_CONTEXTS"
      for ZONE in "${ZONE_CTXS[@]}"; do
          ZONE_NAME=$(echo -n $ZONE | cut -d '=' -f 1)
          ZONE_CTX=$(echo -n $ZONE | cut -d '=' -f 2)

          echo "Installing zone control plane for $ZONE_NAME..."
          kubectl config use-context $ZONE_CTX

          $SCRIPT_PATH/control-planes/zone/install.sh "$ZONE_NAME" "$ZONE_NS" "$SYNC_ENDPOINT"
      done
  else
      echo "Switching to context: $GLOBAL_CONTEXT"
      kubectl config use-context $GLOBAL_CONTEXT

      echo "Installing control plane..."
      kumactl install control-plane --set "kuma.controlPlane.mode=standalone" \
      | kubectl apply -f -
      kubectl wait deployment/kong-mesh-control-plane --namespace $ZONE_NS --for=condition=Available --timeout=60s
  fi

  echo "${COLOR_GREEN}=================================${COLOR_NONE}"
  echo "${COLOR_GREEN}Control planes installed complete.${COLOR_NONE}"
  echo "${COLOR_GREEN}=================================${COLOR_NONE}"
fi


# To configure kumactl:
# kubectl config use-context $GLOBAL_CONTEXT
# kubectl -n kong-mesh-global port-forward svc/kong-mesh-control-plane 5681:5681 &
# kumactl config control-planes add --name kong-mesh --address http://localhost:5681 --skip-verify
