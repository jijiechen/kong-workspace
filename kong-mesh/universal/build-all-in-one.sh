#!/bin/bash



INSTALLER_URL=https://kuma.io/installer.sh
PRODUCT_NAME=kuma
PRODUCT_VERSION=2.11.0

function print_usage(){
  echo "./build.sh [--product <kuma|kong-mesh> --version '2.11.0'"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --product)
      PRODUCT_NAME="$2"
      shift
      shift
      ;;
    --version)
      PRODUCT_VERSION="$2"
      shift
      shift
      ;;
    --help)
      print_usage
      exit 0
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

if [[ "$PRODUCT_NAME" == "kong-mesh" ]]; then
    INSTALLER_URL=https://docs.konghq.com/mesh/installer.sh
fi

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
WORKING_DIR=$(mktemp -d)
echo "WORKING_DIR: $WORKING_DIR"

pushd $(pwd)
cd ${WORKING_DIR}
mkdir -p container
cp ${SCRIPT_PATH}/container/* ${WORKING_DIR}/container/
curl -L ${INSTALLER_URL} | VERSION=${PRODUCT_VERSION} OS=linux sh -
PRODUCT_DIR="${PRODUCT_NAME}-${PRODUCT_VERSION}"

cat << EOF > ./Dockerfile
FROM ubuntu:jammy
RUN apt-get update && apt-get install -y curl && apt-get clean
ADD ${PRODUCT_DIR}/bin/ /usr/local/bin/
RUN useradd -u 5678 -U kuma-dp
RUN mkdir /kuma && \
    echo "# use this file to override default configuration of kuma-cp" > /kuma/kuma-cp.conf && chmod a+rw /kuma/kuma-cp.conf
ADD container/* /kuma
RUN ls /kuma/*.sh | xargs chmod +x
WORKDIR /kuma
CMD [ "/kuma/run.sh" ]
EOF

docker build -t ${PRODUCT_NAME}-all-in-one:${PRODUCT_VERSION} .

popd
