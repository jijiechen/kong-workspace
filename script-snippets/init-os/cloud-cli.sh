#!/bin/bash

# Install gcloud cli
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo  apt-key add -
sudo apt-get update && sudo apt-get install -y google-cloud-cli=452.0.1
sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin


# AWS CLI
ARCH=$(uname -m)
curl "https://awscli.amazonaws.com/awscli-exe-linux-$ARCH.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
if [ "$ARCH" == "aarch64" ]; then
ARCH=arm64
else
ARCH=amd64
fi
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash