#!/bin/bash

# install packages
sudo apt-get install -y jq fzf clang-format gnupg unzip
sudo apt-get install -y build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev libcurl4-openssl-dev libffi-dev python3-pip

# install yq
VERSION=v4.2.0 BINARY=yq_linux_amd64 wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - | tar xz && sudo mv ${BINARY} /usr/bin/yq

ARCH=$(uname -m)
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
if [ "$ARCH" == "aarch64" ]; then
ARCH=arm64
else
ARCH=amd64
fi

# install golang
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
$SCRIPT_PATH/go.sh

# install nodejs
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get install nodejs -y


# install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh --version 23.0 --channel stable
sudo addgroup --system docker
sudo adduser $(whoami) docker
sudo systemctl enable docker


# install kubectl/helm/k3d
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$ARCH/kubectl"
chmod +x kubectl
mkdir -p ~/.local/bin
mv ./kubectl ~/.local/bin/kubectl

curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

curl -sL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
