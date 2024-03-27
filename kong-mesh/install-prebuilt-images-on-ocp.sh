#!/bin/bash

PROJ_NAME=$1
VERSION=$2

REPO_PATH='<REPO_PATH>'
DO_INSTALL=
if [[ "$#" == "1" ]] && [[ "$PROJ_NAME" == "*/*" ]]; then
    DO_INSTALL=1
    REPO_PATH=$1
    FILE_NAME=$($REPO_PATH | rev | awk -F '/' '{print $1}' | rev)
    PROJ_NAME=$(echo $FILE_NAME | awk -F '-0.0.0' '{print $1}')
    VERSION=$(echo $FILE_NAME | awk -F '0.0.0-' '{print $2}')
    VERSION=0.0.0-${VERSION%.tgz}
fi

APPS=(kuma-universal kuma-cni kuma-init kuma-dp kuma-cp kumactl)

# if using an OpenShift cluster, please import its CA cert into system keychain access and trust it
# oc login -u kubeadmin https://api.crc.testing:6443
IAMGE_REPO_PREFIX=kong
if [[ "$PROJ_NAME" == "kuma" ]]; then
    IAMGE_REPO_PREFIX=kumahq
fi

docker login -u $(oc whoami) -p $(oc whoami --show-token) default-route-openshift-image-registry.apps-crc.testing
if [[ -z "$(oc get project | grep $PROJ_NAME-system)" ]]; then
    oc new-project $PROJ_NAME-system --display-name "$PROJ_NAME System"
fi
oc project $PROJ_NAME-system

for APP in "${APPS[@]}"; do
    if [[ -z "$(oc get imagestream -n $PROJ_NAME-system -o Name)" ]]; then
        oc create imagestream $APP
    fi

    docker tag "${IAMGE_REPO_PREFIX}/${APP}:${VERSION}" "default-route-openshift-image-registry.apps-crc.testing/$PROJ_NAME-system/${APP}:${VERSION}"
    docker push "default-route-openshift-image-registry.apps-crc.testing/$PROJ_NAME-system/${APP}:${VERSION}"
done
    
echo ""
echo "All images pushed to OpenShift."
echo ""
echo "If you want to enable pulling image from ${PROJ_NAME}-system namespace, please run the following command:"
echo "Please change 'kuma-demo' to whatever your application ns:"
echo "oc policy add-role-to-user system:image-puller system:serviceaccount:kuma-demo:default -n ${PROJ_NAME}-system"
echo ""
echo ""

SETTINGS_PREFIX=
if [[ "$PROJ_NAME" == "kong-mesh" ]]; then
    SETTINGS_PREFIX=kuma.
fi

if [[ ! -z "$DO_INSTALL" ]]; then
    oc adm policy add-scc-to-user nonroot-v2 system:serviceaccount:kuma-system:kuma-install-crds
    oc adm policy add-scc-to-user nonroot-v2 system:serviceaccount:kuma-system:kuma-patch-ns-job 
    oc adm policy add-scc-to-user nonroot-v2 system:serviceaccount:kuma-system:kuma-pre-delete-job
    oc policy add-role-to-user system:image-puller system:serviceaccount:kube-system:${PROJ_NAME}-cni -n ${PROJ_NAME}-system

    echo "Installing ${PROJ_NAME} control plane..."
    # --set "cni.namespace=openshift-sdn" \
    helm install $PROJ_NAME --namespace $PROJ_NAME-system \
        --set "${SETTINGS_PREFIX}controlPlane.mode=standalone" \
        --set "${SETTINGS_PREFIX}cni.enabled=true" \
        --set "${SETTINGS_PREFIX}cni.containerSecurityContext.privileged=true" \
        --set "${SETTINGS_PREFIX}hooks.containerSecurityContext.allowPrivilegeEscalation=false" \
        --set "${SETTINGS_PREFIX}hooks.containerSecurityContext.capabilities.drop[0]=ALL" \
        --set "${SETTINGS_PREFIX}hooks.containerSecurityContext.seccompProfile.type=RuntimeDefault" \
        --set "global.image.registry=image-registry.openshift-image-registry.svc:5000/$PROJ_NAME-system" \
        $REPO_PATH/.cr-release-packages/${PROJ_NAME}-${VERSION}.tgz
else
    echo "Execute following commands to install the control plane:"
    echo ""
    echo "oc adm policy add-scc-to-user nonroot-v2 system:serviceaccount:kuma-system:kuma-install-crds"
    echo "oc adm policy add-scc-to-user nonroot-v2 system:serviceaccount:kuma-system:kuma-patch-ns-job"
    echo "oc adm policy add-scc-to-user nonroot-v2 system:serviceaccount:kuma-system:kuma-pre-delete-job"
    echo "oc policy add-role-to-user system:image-puller system:serviceaccount:kube-system:${PROJ_NAME}-cni -n ${PROJ_NAME}-system"

    echo "helm install $PROJ_NAME --namespace $PROJ_NAME-system \\"
    echo "    --set \"${SETTINGS_PREFIX}controlPlane.mode=standalone\" \\" 
    echo "    --set \"${SETTINGS_PREFIX}cni.enabled=true\" \\" 
    echo "    --set \"${SETTINGS_PREFIX}cni.containerSecurityContext.privileged=true\" \\"
    echo "    --set \"${SETTINGS_PREFIX}hooks.containerSecurityContext.allowPrivilegeEscalation=false\"  \\"
    echo "    --set \"${SETTINGS_PREFIX}hooks.containerSecurityContext.capabilities.drop[0]=ALL\" \\"
    echo "    --set \"${SETTINGS_PREFIX}hooks.containerSecurityContext.seccompProfile.type=RuntimeDefault\"  \\"
    echo "    --set \"global.image.registry=image-registry.openshift-image-registry.svc:5000/$PROJ_NAME-system\" \\"
    echo "  \"$REPO_PATH/.cr-release-packages/${PROJ_NAME}-${VERSION}.tgz\""
fi


