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
# WORKING_DIR=$(realpath ./build)
echo "WORKING_DIR: $WORKING_DIR"

pushd $(pwd)
cd ${WORKING_DIR}
mkdir -p container
cp ${SCRIPT_PATH}/container/* ${WORKING_DIR}/container/

curl -L -o kuma-source.zip https://github.com/kumahq/kuma/archive/refs/tags/${PRODUCT_VERSION}.zip && unzip kuma-source.zip && rm kuma-source.zip
(cd kuma-${PRODUCT_VERSION} && GOOS=linux go build -o testserver test/server/main.go)

curl -L ${INSTALLER_URL} | VERSION=${PRODUCT_VERSION} OS=linux sh -
PRODUCT_DIR="${PRODUCT_NAME}-${PRODUCT_VERSION}"

cat << EOF > ./Dockerfile
FROM ubuntu:jammy
RUN apt update \
  && apt dist-upgrade -y \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    iproute2 \
    iptables \
    tzdata \
    vim \
  && apt clean \
  && rm -rf /var/lib/apt/lists/*

# Create the kuma-dp user and make Envoy able to write to stdout when running with a non-root user
# https://github.com/moby/moby/issues/31243#issuecomment-406879017
# this container needs to be run with a tty (-t)
RUN useradd -u 5678 -U kuma-dp && usermod -a -G tty kuma-dp
RUN mkdir /kuma && \
    echo "# use this file to override default configuration of kuma-cp" > /kuma/kuma-cp.conf && chmod a+rw /kuma/kuma-cp.conf
ADD ${PRODUCT_DIR}/bin/ /usr/local/bin/
ADD kuma-${PRODUCT_VERSION}/testserver /usr/local/bin/
ADD container/* /kuma
RUN ls /kuma/*.sh | xargs chmod +x
WORKDIR /kuma
CMD [ "/kuma/run.sh" ]
EOF

docker build -t ${PRODUCT_NAME}-all-in-one:${PRODUCT_VERSION} .

popd
